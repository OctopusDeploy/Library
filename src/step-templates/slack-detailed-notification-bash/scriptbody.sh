# Get values into variables
includeFieldProject=$(get_octopusvariable "IncludeFieldProject")
includeFieldEnvironment=$(get_octopusvariable "IncludeFieldEnvironment")
includeFieldMachine=$(get_octopusvariable "includeFieldMachine")
includeFieldTenant=$(get_octopusvariable "IncludeFieldTenant")
includeFieldUsername=$(get_octopusvariable "IncludeFieldUsername")
includeFieldRelease=$(get_octopusvariable "IncludeFieldRelease")
includeFieldReleaseNotes=$(get_octopusvariable "IncludeFieldReleaseNotes")
includeFieldErrorMessageOnFailure=$(get_octopusvariable "IncludeErrorMessageOnFailure")
includeFieldLinkOnFailure=$(get_octopusvariable "IncludeLinkOnFailure")

function convert_ToBoolean () {
	local stringValue=$1
    local returnValue=""

    if [[ "$stringValue" == "True" ]]
    then
    	returnValue=true
    else
    	returnValue=false
    fi
    
    echo "$returnValue"
}

function slack_Populate_StatusInfo (){
    	local success=$1
    	local deployment_info=$(get_octopusvariable "DeploymentInfoText")
		local jsonBody="{ "
		
        if [[ "$success" == true ]]
        then
        	jsonBody+='"color": "good",'
            jsonBody+='"title": "Success",'
            jsonBody+='"fallback": "Deployed successfully '
            jsonBody+="$deployment_info\""
        else
        	jsonBody+='"color": "danger",'
            jsonBody+='"title": "Failed",'
            jsonBody+='"fallback": "Failed to deploy '
            jsonBody+="$deployment_info\""
        fi
        
        #jsonBody+="}"
        
        echo $jsonBody
}

function populate_field () {
	local title=$1
    local value=$2
    local body=""
    
    body+='{'
    body+='"short": "true",'
    body+='"title": '
    body+="\"$title\""
    body+=","
    body+='"value": '
    body+="\"$value\""
    body+='}'
    
    echo "$body"
}


function slack_Populate_Fields (){
	local status_info=$1
    local fieldsJsonBody=""
    declare -a testArray
    
   if [[ "$includeFieldProject" == true ]]
   then
    testArray+=("$(populate_field "Project" "$(get_octopusvariable "Octopus.Project.Name")")")
   fi
    
   if [[ "$includeFieldEnvironment" == true ]]
   then
    testArray+=("$(populate_field "Environment" "$(get_octopusvariable "Octopus.Environment.Name")")")
   fi
   
   if [[ "$includeFieldMachine" == true ]]
   then
    testArray+=("$(populate_field "Machine" "$(get_octopusvariable "Octopus.Machine.Name")")")
   fi
      
   if [[ "$includeFieldTenant" == true ]]
   then
    testArray+=("$(populate_field "Tenant" "$(get_octopusvariable "Octopus.Deployment.Tenant.Name")")")
   fi
   
   if [[ "$includeFieldUsername" == true ]]
   then
    testArray+=("$(populate_field "Username" "$(get_octopusvariable "Octopus.Deployment.CreatedBy.Username")")")
   fi
   
   if [[ "$includeFieldRelease" == true ]]
   then
    testArray+=("$(populate_field "Release" "$(get_octopusvariable "Octopus.Release.Number")")")
   fi
   
   if [[ "$includeFieldReleaseNotes" == true ]]
   then
    testArray+=("$(populate_field "Changes in this release" "$(get_octopusvariable "Octopus.Release.Notes")")")
   fi
      
   if [[ "$status_info" == false ]]
   then
     if [[ "$includeFieldErrorMessageOnFailure" == true ]]
     then
      testArray+=("$(populate_field "Error text" "$(get_octopusvariable "Octopus.Deployment.Error")")")
     fi

     if [[ "$includeFieldLinkOnFailure" == true ]]
     then
      baseUrl="$(get_octopusvariable "Octopus.Web.ServerUri")"
      testArray+=("$(populate_field "See the process" "$baseUrl$(get_octopusvariable "Octopus.Web.DeploymentLink")")")
     fi
   fi
   
   
   ( IFS=$','; echo "${testArray[*]}" )   
   
}

function slack_rich_notification () {
	local success=$1
    local jsonBody="{ "
    
    jsonBody+='"channel": '
    jsonBody+="\"$(get_octopusvariable "Channel")\","
    jsonBody+='"username": '
    jsonBody+="\"$(get_octopusvariable "Username")\","
    jsonBody+='"icon_url": '
    jsonBody+="\"$(get_octopusvariable "IconUrl")\","
    jsonBody+='"attachments": ['
    jsonBody+=$(slack_Populate_StatusInfo "$success")
    jsonBody+=',"fields": '
    jsonBody+="[$(slack_Populate_Fields "$success")]"
    jsonBody+="}]}"
    
    echo "$jsonBody"
}

# Convert include* variables to actual boolean values
includeFieldProject=$(convert_ToBoolean "$includeFieldProject")
includeFieldEnvironment=$(convert_ToBoolean "$includeFieldEnvironment")
includeFieldMachine=$(convert_ToBoolean "$includeFieldMachine")
includeFieldTenant=$(convert_ToBoolean "$includeFieldTenant")
includeFieldUsername=$(convert_ToBoolean "$includeFieldUsername")
includeFieldRelease=$(convert_ToBoolean "$includeFieldRelease")
includeFieldReleaseNotes=$(convert_ToBoolean "$includeFieldReleaseNotes")
includeFieldErrorMessageOnFailure=$(convert_ToBoolean "$includeFieldErrorMessageOnFailure")
includeFieldLinkOnFailure=$(convert_ToBoolean "$includeFieldLinkOnFailure")

success=true

if [[ ! -z $(get_octopusvariable "Octopus.Deployment.Error") ]]
then
	success=false
fi

# Build json payload
json_payload=$(slack_rich_notification $success)

webook_url=$(get_octopusvariable "HookUrl")

# Send webhook - redirect stderr to stdout
wget --post-data="$json_payload" --secure-protocol="auto" "$webook_url" 2>&1

# Check for error
if [[ $? -ne 0 ]]
then
    fail_step "Failed!"
fi

