if ([string]::IsNullOrWhitespace($CreateK8sTargetNamespace)) {
	Write-Error "The namespace variable must be defined"
    exit 1
}

if ([string]::IsNullOrWhitespace($CreateK8sTargetRole)) {
	Write-Error "The role variable must be defined"
    exit 1
}

$target = if ([string]::IsNullOrEmpty($CreateK8sTargetName)) {"$($CreateK8sTargetNamespace)-k8s"} else {$CreateK8sTargetName}
$serviceaccount = "$($CreateK8sTargetNamespace)-deployer"
$rolename = "$($CreateK8sTargetNamespace)-deployer-role"
$binding = "$($CreateK8sTargetNamespace)-deployer-binding"

$count = (kubectl get namespaces -o json |
	ConvertFrom-JSON |
    Select-Object -ExpandProperty items |
    ? {$_.metadata.name -eq $CreateK8sTargetNamespace}).Count
    
if ($count -eq 0) {
  Set-Content -Path namespace.yaml -Value @"
  apiVersion: v1
  kind: Namespace
  metadata:
    name: $CreateK8sTargetNamespace
"@

  if (![string]::IsNullOrWhitespace($CreateK8sTargetNamespaceAnnotations)) {
  	Add-Content -Path namespace.yaml -Value @"
    annotations:
"@
	$annotations = ($CreateK8sTargetNamespaceAnnotations -split '\r?\n').Trim()
    foreach ($annotation in $annotations) {
        Add-Content -Path namespace.yaml -Value @"
      $annotation
"@
    }
  }

  kubectl apply -f namespace.yaml
}

Set-Content -Path serviceaccount.yaml -Value @"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $serviceaccount
  namespace: $CreateK8sTargetNamespace 
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: $CreateK8sTargetNamespace 
  name: $rolename
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $binding
  namespace: $CreateK8sTargetNamespace 
subjects:
- kind: ServiceAccount
  name: $serviceaccount
  apiGroup: ""
roleRef:
  kind: Role
  name: $rolename
  apiGroup: ""
"@

kubectl apply -f serviceaccount.yaml
 
Set-Content -Path secret.yaml -Value @"
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: $serviceaccount
  namespace: $CreateK8sTargetNamespace
  annotations:
    kubernetes.io/service-account.name: "$serviceaccount"
"@

kubectl apply -f secret.yaml

$data = kubectl get secret $serviceaccount -o jsonpath="{.data.token}" --namespace=$CreateK8sTargetNamespace 

$token = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($data))
$url = (kubectl config view -o json | ConvertFrom-Json).clusters[0].cluster.server

New-OctopusTokenAccount -Name $target -token $token -updateIfExisting

if ([string]::IsNullOrEmpty("#{Octopus.Action.Kubernetes.CertificateAuthority}") -or "#{Octopus.Action.Kubernetes.AksAdminLogin}" -ieq "True") {
	New-OctopusKubernetesTarget `
		-name $target `
		-clusterUrl $url `
		-octopusRoles $CreateK8sTargetRole `
		-octopusAccountIdOrName $target `
		-namespace $CreateK8sTargetNamespace `
		-updateIfExisting `
		-skipTlsVerification True `
		-octopusDefaultWorkerPoolIdOrName "#{Octopus.WorkerPool.Id}" `
        -healthCheckContainerImageFeedIdOrName "$CreateK8sTargetContainerImageFeed" `
    	-healthCheckContainerImage "$CreateK8sTargetContainerImage"
} else {
	New-OctopusKubernetesTarget `
		-name $target `
		-clusterUrl $url `
		-octopusRoles $CreateK8sTargetRole `
		-octopusAccountIdOrName $target `
		-namespace $CreateK8sTargetNamespace `
		-updateIfExisting `
        -octopusServerCertificateIdOrName "#{Octopus.Action.Kubernetes.CertificateAuthority}" `
		-octopusDefaultWorkerPoolIdOrName "#{Octopus.WorkerPool.Id}" `
        -healthCheckContainerImageFeedIdOrName "$CreateK8sTargetContainerImageFeed" `
    	-healthCheckContainerImage "$CreateK8sTargetContainerImage"
}