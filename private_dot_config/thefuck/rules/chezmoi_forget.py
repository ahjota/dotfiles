from thefuck.utils import for_app

@for_app('chezmoi')
def match(command):
    return 'remove' in command.script

def get_new_command(command):
    return [
        command.script.replace('remove', 'forget'),
        command.script.replace('remove', 'destroy'),
    ]
