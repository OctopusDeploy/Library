rclonePath=$(get_octopusvariable "Rclone.Path")
rcloneCommand=$(get_octopusvariable "Rclone.Command")
rcloneParameters=$(get_octopusvariable "Rclone.Parameters")
printCommand=$(get_octopusvariable "Rclone.PrintCommand")

if [ ! -z "$rclonePath" ] ; then
   	PATH=$rclonePath:$PATH
fi

if [ -z "$rcloneCommand" ] ; then
   	fail_step "Command is a required paremeter."
fi

if [ "$printCommand" = "True" ] ; then
    set -x
fi

rclone $rcloneCommand ${rcloneParameters:+ $rcloneParameters} 2>&1

# Check for error
if [[ $? -ne 0 ]]
then
    fail_step "The rclone command resulted in errors. Please review the logs above."
fi
