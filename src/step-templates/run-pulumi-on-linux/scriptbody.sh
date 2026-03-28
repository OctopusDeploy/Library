# Check if the pulumi command is in the path and if not, download and install it.
# Additionally, add pulumi to the path.
if ! [ -x "$(command -v pulumi)" ]; then
	curl -fsSL https://get.pulumi.com | sh
    export PATH=$PATH:$HOME/.pulumi/bin
	echo "Pulumi version: $(pulumi version)"
fi

accessToken=$(get_octopusvariable "Pulumi.AccessToken")
if [ -z "${accessToken:-}" ]; then
	fail_step "Pulumi Access Token must be specified."
fi
export PULUMI_ACCESS_TOKEN=$accessToken

# Check for AWS access key credentials and set those in the env.
export AWS_ACCESS_KEY_ID=$(get_octopusvariable "AWS.AccessKey")
export AWS_SECRET_ACCESS_KEY=$(get_octopusvariable "AWS.SecretKey")

# Check for Azure SP/personal account credentials and set those in the env.
export ARM_SUBSCRIPTION_ID=$(get_octopusvariable "Azure.SubscriptionNumber")
export ARM_TENANT_ID=$(get_octopusvariable "Azure.TenantId")
export ARM_CLIENT_ID=$(get_octopusvariable "Azure.Client")
export ARM_CLIENT_SECRET=$(get_octopusvariable "Azure.Password")

if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
	if [ -z "${ARM_CLIENT_SECRET:-}" ]; then
    	fail_step "Neither secrets for AWS or Azure were detected."
    fi
fi

pulumi login

cwd=$(get_octopusvariable "Pulumi.WorkingDirectory")
if [ -n "${cwd:-}" ]; then
	pushd $cwd
fi

restoreDeps=$(get_octopusvariable "Pulumi.Restore")
if [ "$restoreDeps" = "True" ]; then
	echo "Restoring dependencies..."
	npm install
fi

createStackIfNotExists=$(get_octopusvariable "Pulumi.CreateStack")
stackName=$(get_octopusvariable "Pulumi.StackName")
echo "Selecting stack $stackName"
pulumi stack select $stackName || (
	if [ "$createStackIfNotExists" = "True" ]; then
    	pulumi stack init $stackName
    fi
)

pulCmd=$(get_octopusvariable "Pulumi.Command")
pulArgs=$(get_octopusvariable "Pulumi.Args")
if [ -n "${pulArgs:-}" ]; then
	pulumi $pulCmd $pulArgs
else
	pulumi $pulCmd
fi

# If a working directory was specified, we would have `pushd`, so let's `popd` now.
if [ -n "${cwd:-}" ]; then
	popd
fi
