if test -f "#{Octopus.Action.Package[OpsLevel].ExtractedPath}/opslevel"; then
	chmod +x #{Octopus.Action.Package[OpsLevel].ExtractedPath}/opslevel
	cat << EOF | #{Octopus.Action.Package[OpsLevel].ExtractedPath}/opslevel create deploy --log-level=WARN -i #{OL_INTEGRATION_URL} -f -
service: #{OL_SERVICE}
description: #{OL_DESCRIPTION}
environment: #{OL_ENVIRONMENT}
deploy-number: #{OL_DEPLOY_NUMBER}
deploy-url: #{OL_DEPLOY_URL}
dedup-id: #{OL_DEDUP_ID}
deployer:
  name: #{OL_DEPLOYER_NAME}
  email: #{OL_DEPLOYER_EMAIL}
#{if Octopus.Release.Package}
#{if Octopus.Release.Package[].Commits}
commit:
  sha: "#{Octopus.Release.Package[0].Commits[0].CommitId}"
  message: "#{Octopus.Release.Package[0].Commits[0].Comment}"
#{/if}
#{/if}
EOF
else
	echo "Please ensure the `opslevel` CLI package is setup and installed!"
fi