$DeployTag = $AwsDeployPrefix + $OctopusParameters["Octopus.Environment.Name"]

#{each action in Octopus.Action}
    #{each package in action.Package}
        Write-Output "Package #{package.PackageId} at version #{package.PackageVersion}"

        $Image = Get-ECRImageBatch -ImageId @{ imageTag="#{package.PackageVersion}" } -RepositoryName "#{package.PackageId}"
        $ImageDeploy = Get-ECRImageBatch -ImageId @{ imageTag=$DeployTag } -RepositoryName "#{package.PackageId}"

        if($Image.Images[0].ImageId.ImageDigest -ne $ImageDeploy.Images[0].ImageId.ImageDigest) {
            Write-Output "Setting tag $DeployTag on image $($Image.Images[0].ImageId.ImageDigest)"
            $Manifest = $Image.Images[0].ImageManifest
            Write-ECRImage -RepositoryName "#{package.PackageId}" -ImageManifest $Manifest -ImageTag $DeployTag
        }
	#{/each}
#{/each}
