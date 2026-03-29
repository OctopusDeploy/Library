uri=$(get_octopusvariable "uri")
expectedCode=$(get_octopusvariable "expectedCode")
timeout=$(get_octopusvariable "timeout")
success=false

# required arguments checking
if [[ $expectedCode == "Unrecognized variable"* ]] || [[ $uri == "Unrecognized variable"* ]] || [[ $timeout == "Unrecognized variable"* ]]
then
    echo "[ERROR]: Missing required argument. Exit!"
    exit 1;
fi

echo "Starting verification request to $uri"
echo "Expecting response code $expectedCode"

end=$((SECONDS+$timeout))

until $success || [ $SECONDS -ge $end ];
do
    code=$(curl --write-out %{http_code} --silent --output /dev/null $uri)
    echo "Recieved response code: $code"
    
    if [ $code -eq $expectedCode ]
    then
        echo "Sucesss! Found status code $expectedCode"
        success=true
        exit 0
    else
        echo "Trying again in 5 seconds..."
        sleep 5
    fi
done

if ! $success
then
    echo "Verification failed - giving up."
    exit 1
fi