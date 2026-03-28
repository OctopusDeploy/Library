services=$(get_octopusvariable "services")
failed=false

# required arguments checking
if [[ $services == "Unrecognized variable"* ]]
then
    echo "[ERROR]: Missing required argument. Exit!"
    exit 1;
fi

for service in ${services//,/ }
do
    if (( $(ps -ef | grep -v grep | grep $service | wc -l) > 0 ))
    then
        echo "$service is running!!!"
    else
        echo "$service is not running!!!"
        failed=true
    fi
done

if $failed; then
    echo "At least one service is not running!!!"
    exit 1
fi
