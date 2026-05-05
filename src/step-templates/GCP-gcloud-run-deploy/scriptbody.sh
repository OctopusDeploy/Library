account=$(get_octopusvariable "GCloudRunDeploy.Account")
project=$(get_octopusvariable "GCloudRunDeploy.Project")
region=$(get_octopusvariable "GCloudRunDeploy.Region")

service=$(get_octopusvariable "GCloudRunDeploy.Service")
image=$(get_octopusvariable "Octopus.Action.Package[GCloudRunDeploy.Container].Image")
additionalParams=$(get_octopusvariable "GCloudRunDeploy.AdditionalParameters")
printCommand=$(get_octopusvariable "GCloudRunDeploy.PrintCommand")

if [ "$account" = "" ] ; then
    fail_step "'Account' is a required parameter for this step."
fi

if [ "$project" = "" ] ; then
    fail_step "'Project' is a required parameter for this step."
fi

if [ "$region" = "" ] ; then
    fail_step "'Region' is a required parameter for this step."
fi

if [ "$service" = "" ] ; then
    fail_step "'Service' is a required parameter for this step."
fi

if [ "$printCommand" = "True" ] ; then
    set -x
fi

gcloud run deploy $service --image=$image ${additionalParams:+ $additionalParams}