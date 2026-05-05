Write-Output "Adding Service fabric cluster certificate"
Write-Output "Resource group name: " $OctopusParameters["Azure.AddServiceFabricClusterCertificate.ResourceGroupName"]
Write-Output "Service fabric cluster name:" $OctopusParameters["Azure.AddServiceFabricClusterCertificate.ClusterName"]
Write-Output "Certificate secret identifier:" $OctopusParameters["Azure.AddServiceFabricClusterCertificate.SecretIdentifier"]

Add-AzureRmServiceFabricClusterCertificate -ResourceGroupName $OctopusParameters["Azure.AddServiceFabricClusterCertificate.ResourceGroupName"] `
	-Name $OctopusParameters["Azure.AddServiceFabricClusterCertificate.ClusterName"] `
    -SecretIdentifier $OctopusParameters["Azure.AddServiceFabricClusterCertificate.SecretIdentifier"]