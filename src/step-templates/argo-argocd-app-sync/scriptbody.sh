# argocd is required
if ! [ -x "$(command -v argocd)" ]; then
	fail_step 'argocd command not found'
fi

# Helper functions
isSet() { [ ! -z "${1}" ]; }
isNotSet() { [ -z "${1}" ]; }

# Get variables
argocd_server=$(get_octopusvariable "ArgoCD.AppSync.ArgoCD_Server")
argocd_authToken=$(get_octopusvariable "ArgoCD.AppSync.ArgoCD_Auth_Token")
applicationSelector=$(get_octopusvariable "ArgoCD.AppSync.ApplicationSelector")
additionalParameters=$(get_octopusvariable "ArgoCD.AppSync.AdditionalParameters")

# Check required variables
if isNotSet "${argocd_server}"; then
  fail_step "argocd_server is not set"
fi

if isNotSet "${argocd_authToken}"; then
  fail_step "argocd_authToken is not set"
fi

if isNotSet "${applicationSelector}"; then
  fail_step "applicationSelector is not set"
fi

if isSet "${additionalParameters}"; then
  IFS=$'\n' read -rd '' -a additionalArgs <<< "$additionalParameters"
else
  additionalArgs=()
fi

flattenedArgs="${additionalArgs[@]}"

write_verbose "ARGOCD_SERVER: '${argocd_server}'"
write_verbose "ARGOCD_AUTH_TOKEN: '********'"

authArgs="--server ${argocd_server} --auth-token ${argocd_authToken}"
maskedAuthArgs="--server ${argocd_server} --auth-token '********'"

echo "Executing: argocd app sync ${applicationSelector} ${maskedAuthArgs} ${flattenedArgs}"
argocd app sync ${applicationSelector} ${authArgs} ${flattenedArgs}