# Get variables
tomcatManagerUrl=$(get_octopusvariable "Tomcat.Undeploy.ManagerUrl")
tomcatManagementUser=$(get_octopusvariable "Tomcat.Undeploy.Management.User")
tomcatManagementPassword=$(get_octopusvariable "Tomcat.Undeploy.Management.Password")
contextPath=$(get_octopusvariable "Tomcat.Undeploy.ContextPath")
deploymentVersion=$(get_octopusvariable "Tomcat.Undeploy.DeploymentVersion")
applicationFound=false
displayMessage="$contextPath"

# Get list of applications
echo "Checking Tomcat for $contextPath ..."
listUrl="$tomcatManagerUrl/text/list"

results=$(curl $listUrl --user "$tomcatManagementUser":"$tomcatManagementPassword" 2>&1)

# Break results into an array
IFS=$'\n' resultArray=($results)

# Loop through results
for i in "${resultArray[@]}"
do
	# Check for context path
    if [[ "$i" == *"$contextPath"* ]]
    then
    	# Check to see if there was a version specified
        if [[ "$deploymentVersion" != "" ]]
        then
        	displayMessage="$displayMessage $deploymentVersion"
        	# Check for version
            if [[ "$i" == *"$deploymentVersion"* ]]
            then
            	echo "Found $contextPath with version $deploymentVersion ..."
                applicationFound=true
                break
            fi
        else
        	if [[ "$i" != *"##"* ]]
            then
            	echo "Found $contextPath ..."
            	applicationFound=true
            	break
            fi
        fi
    fi
done

if [[ "$applicationFound" == true ]]
then
	# Create URL
	undeployUrl="$tomcatManagerUrl/text/undeploy?path=/$contextPath"
    
	# Check to see if a version was specified
	if [[ "$deploymentVersion" != "" ]]
	then
		undeployUrl="$undeployUrl&version=$deploymentVersion"
	fi

	# Let user know what's going on
	echo "Removing $displayMessage ..."

	# Call the undeploy for Tomcat
	curl "$undeployUrl" --user "$tomcatManagementUser":"$tomcatManagementPassword" 2>&1
else
	echo "Unable to find $displayMessage ..."
fi