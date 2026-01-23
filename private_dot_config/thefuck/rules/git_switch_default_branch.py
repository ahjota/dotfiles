import subprocess
from thefuck.utils import for_app, replace_argument

@for_app('git')
def match(command):
    return ('switch' in command.script and 
            'fatal: invalid reference:' in command.output and
            ('main' in command.output or 'master' in command.output))

def _get_default_branch():
    """Get the default branch, trying git default-branch alias first, then symbolic-ref."""
    # Try git default-branch alias first
    try:
        result = subprocess.run(
            ['git', 'default-branch'],
            capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    
    # Fall back to symbolic-ref
    try:
        result = subprocess.run(
            ['git', 'symbolic-ref', 'refs/remotes/origin/HEAD'],
            capture_output=True, text=True)
        if result.returncode == 0:
            # refs/remotes/origin/master -> master
            return result.stdout.strip().split('/')[-1]
    except Exception:
        pass
    return None

def get_new_command(command):
    # Determine which branch was attempted
    if 'main' in command.output:
        attempted = 'main'
        fallback = 'master'
    else:
        attempted = 'master'
        fallback = 'main'
    
    # Try to get actual default branch
    default_branch = _get_default_branch()
    
    if default_branch and default_branch != attempted:
        return replace_argument(command.script, attempted, default_branch)
    
    # Fallback: swap main <-> master
    return replace_argument(command.script, attempted, fallback)
