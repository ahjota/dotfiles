from thefuck.utils import for_app

@for_app('gh')
def match(command):
    return 'repo checkout' in command.script

def get_new_command(command):
    return command.script.replace('repo checkout', 'repo clone')
