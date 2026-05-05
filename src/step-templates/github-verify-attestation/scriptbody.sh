token=$(get_octopusvariable "VerifyAttestation.Token")
package=$(get_octopusvariable "Octopus.Action.Package[VerifyAttestation.Package].PackageFilePath")
owner=$(get_octopusvariable "VerifyAttestation.Owner")
repo=$(get_octopusvariable "VerifyAttestation.Repo")
flags=$(get_octopusvariable "VerifyAttestation.Flags")
printCommand=$(get_octopusvariable "VerifyAttestation.PrintCommand")
createArtifact=$(get_octopusvariable "VerifyAttestation.CreateArtifact")
deploymentId="#{Octopus.Deployment.Id | ToLower}"
stepName=$(get_octopusvariable "Octopus.Step.Name")

echoerror() { echo "$@" 1>&2; }

export GITHUB_TOKEN=$token

if ! command -v gh &> /dev/null
then
    echoerror "gh could not be found, please ensure that it is installed on your worker or in the execution container image"
    exit 1
fi

if [ "$token" = "" ] ; then
    fail_step "'GitHub Access Token' is a required parameter for this step."
fi

if [ "$owner" = "" ] &&  [ "$repo" = "" ]; then
    fail_step "Either 'Owner' or 'Repo' must be provided to this step."
fi


gh_cmd="gh attestation verify $package ${owner:+ -o $owner} ${repo:+ -R $owner} --format json ${flags:+ $flags}"

if [ "$printCommand" = "True" ] ; then
  echo $gh_cmd
fi

json=$($gh_cmd)

if [ $? = 0 ]
then
  set_octopusvariable "Json" $json
  echo "Created output variable: ##{Octopus.Action[$stepName].Output.Json}"

  if [ "$createArtifact" = "True" ] ; then
    echo $json > "$PWD/attestation-$deploymentId.json"
    new_octopusartifact "$PWD/attestation-$deploymentId.json"
  fi
else
  fail_step "Failed to verify attestation for $package"
fi