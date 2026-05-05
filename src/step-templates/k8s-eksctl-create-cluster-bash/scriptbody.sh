clusterName='#{eksctl.cluster.name}'
region='#{eksctl.region}'
kubeConfig='eks-sandbox.yaml'
eksctlYaml='eksctl.yaml'


# eksctl is required
if ! [ -x "$(command -v eksctl)" ]; then
	fail_step 'eksctl command not found'
fi

# yq is required
if ! [ -x "$(command -v yq)" ]; then
	fail_step 'yq command not found'
fi

cat >"./$eksctlYaml" <<EOL
#{eksctl.yaml}
EOL

# Check to see if the cluster exists
echo "Checking to see if cluster '$clusterName' exists"
eksctl get cluster --name $clusterName --region $region 2>&1

if [ $? -ne 0 ]
then
	echo "Cluster does not exist. Creating cluster..."
    eksctl create cluster -f $eksctlYaml --kubeconfig $kubeConfig
else
	echo "Cluster exists. Reading cluster details..."
    eksctl utils write-kubeconfig --cluster $clusterName --kubeconfig $kubeConfig 
fi

if [ ! -f $kubeConfig ]
then
	echo "$kubeConfig does not exist, so the Kubernetes target can not be created!"
	exit 1
fi

accountId=$(get_octopusvariable '#{eksctl.account}')
workerPool=$(get_octopusvariable 'eksctl.octopus.target.defaultWorkerPool')
clusterUrl=$(yq r $kubeConfig 'clusters[0].cluster.server')

# Write service message to create the k8s target
echo "##octopus[create-kubernetestarget \
    name=\"$(encode_servicemessagevalue '#{eksctl.octopus.target.name}')\" \
    octopusRoles=\"$(encode_servicemessagevalue '#{eksctl.octopus.target.roles}')\" \
    clusterName=\"$(encode_servicemessagevalue "$clusterName")\" \
    clusterUrl=\"$(encode_servicemessagevalue "$clusterUrl")\" \
    octopusAccountIdOrName=\"$(encode_servicemessagevalue "$accountId")\" \
    namespace=\"$(encode_servicemessagevalue 'default')\" \
    octopusDefaultWorkerPoolIdOrName=\"$(encode_servicemessagevalue "$workerPool")\" \
    updateIfExisting=\"$(encode_servicemessagevalue 'True')\" \
    skipTlsVerification=\"$(encode_servicemessagevalue 'True')\"]"