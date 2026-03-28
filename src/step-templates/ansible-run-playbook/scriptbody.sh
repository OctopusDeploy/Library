ansibleInstalled=$(which -a ansible-playbook >/dev/null; echo $?)

if [ $ansibleInstalled -ne 0 ];then
	echo "Ansible Not Installed"
    exit 1;
fi


ansible-playbook $(get_octopusvariable "RunAnsible.Playbook.Path")
playbookRC=$?

if [ $playbookRC -ne 0 ]; then
  exit $playbookRC;
fi