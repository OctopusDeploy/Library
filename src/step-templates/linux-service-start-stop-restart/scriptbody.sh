serviceName=$(get_octopusvariable "templateServiceName")
action=$(get_octopusvariable "templateAction")
sleepInSeconds=$(get_octopusvariable "templateSleepInSeconds")

function get_service_running () {
	local linuxService=$1
    local state=$(systemctl is-active "$linuxService")


    if [[ $state == "active" ]]
    then
        state=true
    else
        state=false
    fi

  	# Return the result
    echo "$state"
}

function service_found () {
	local serviceName=$1
	local result=""

	if [[ ! -z $(systemctl status $serviceName | grep "$serviceName") ]]
	then
		result=true
	else
		result=false
	fi

	echo "$result"
}

# Check for service
if [[ $(service_found "$serviceName") == true ]]
then
	# Perform action
	case $action in
		start)
			if [[ $(get_service_running "$serviceName") == false ]]
			then 
				echo "Starting service $serviceName..."
				systemctl start $serviceName

				sleep $sleepInSeconds

				if [[ $(get_service_running "$serviceName") == true ]]
				then
					echo "$serviceName started successfully."
				else
					fail_step "$serviceName did not start within the specified wait time."
				fi
			else
				fail_step "Service $serviceName is already running!"
			fi
			;;
		stop)
			if [[ $(get_service_running "$serviceName") == true ]]
			then
				echo "Stopping $serviceName..."
				systemctl stop $serviceName

				sleep $sleepInSeconds

				if [[ $(get_service_running "$serviceName") == false ]]
				then
					echo "Stopped $serviceName successfully."
				else
					fail_step "$serviceName failed to stop within the specified wait time."
				fi
			else
				fail_step "Service $serviceName is not running!"
			fi
			;;

		restart)
			if [[ $(get_service_running "$serviceName") == true ]]
			then
				echo "Restarting $serviceName..."
				systemctl restart $serviceName

				sleep $sleepInSeconds

				if [[ $(get_service_running "$serviceName") == true ]]
				then
					echo "Restarted $serviceName successfully."
				else
					fail_step "$serviceName did not restart within the specified wait time"
				fi
			else
				fail_step "$serviceName is stopped!"
			fi
			;;


		*)
			fail_step "Invalid action.  Valid actions are start|stop|restart."
			;;
	esac
else
	fail_step "Service $serviceName not found!"
fi