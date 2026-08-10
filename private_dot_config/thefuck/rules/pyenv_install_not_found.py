import re
from thefuck.utils import for_app, replace_command


@for_app('pyenv', at_least=2)
def match(command):
    return ('install' in command.script_parts and
            'definition not found' in command.output)


def _extract_versions(output):
    """Extract version names from pyenv's 'definition not found' output."""
    block = re.search(
        r"The following versions contain.*?:\n((?:\s+\S+\s*\n)+)",
        output)
    if block:
        return [line.strip() for line in block.group(1).strip().split('\n')]
    return []


def get_new_command(command):
    requested = command.script_parts[-1]
    versions = [v for v in _extract_versions(command.output)
                if v.startswith(requested)]

    commands = replace_command(command, requested, versions or
                               _extract_versions(command.output))
    commands.append('pyenv install --list')
    commands.append('brew update && brew upgrade pyenv')
    return commands
