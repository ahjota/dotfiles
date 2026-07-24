from thefuck.utils import for_app

@for_app('chezmoi')
def match(command):
    return 'remove' in command.script or 'delete' in command.script

def get_new_command(command):
    script = command.script
    for word in ['remove', 'delete']:
        if word in script:
            return [
                script.replace(word, 'forget'),
                script.replace(word, 'destroy'),
            ]
