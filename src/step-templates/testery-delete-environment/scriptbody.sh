set -e

export PATH="$HOME/.local/bin:$PATH"

pip install --user testery --upgrade

testery delete-environment --token $(get_octopusvariable "TesteryToken") --key $(get_octopusvariable "TesteryKey")