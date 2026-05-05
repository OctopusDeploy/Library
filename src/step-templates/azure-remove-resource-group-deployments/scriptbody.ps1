function Get-Param($Name, [switch]$Required, $Default) {
    $result = $null

    if ($null -ne $OctopusParameters) {
        $result = $OctopusParameters[$Name]
    }

    if ($null -eq $result) {
        $variable = Get-Variable $Name -EA SilentlyContinue
        if ($null -ne $variable) {
            $result = $variable.Value
        }
    }

    if ($null -eq $result) {
        if ($Required) {
            throw "Missing parameter value $Name"
        }
        else {
            $result = $Default
        }
    }

    return $result
}

Function Get-Deployments {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$resourceGroupName
    )
    $listOfDeployments = Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName
    $azureDeploymentNameAndDate = @()
    $listOfDeployments | ForEach-Object { $azureDeploymentNameAndDate += [PSCustomObject]@{DeploymentName = $_.DeploymentName; Time = $_.Timestamp } }

    return $azureDeploymentNameAndDate
}

Function Remove-AzureRmResourceDeployments {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$resourceGroupName,

        [ValidateRange(0, 800)]
        [int]$numberOfDeploymentsToKeep,

        [int]$numberOfDaysToKeep
    )

    if ($null -ne $($numberOfDaysToKeep) -and $($numberOfDaysToKeep) -gt 0) {
        $azureDeploymentNameAndDate = Get-Deployments $resourceGroupName

        Write-Output "Found $($azureDeploymentNameAndDate.Count) deployments from the $resourceGroupName resource group"

        $itemsToRemove = $azureDeploymentNameAndDate | Where-Object { $_.Time -lt ((get-date).AddDays( - $($numberOfDaysToKeep))) }
        $numberOfItemsToRemove = $itemsToRemove | Measure-Object

        if ($numberOfitemsToRemove.Count -eq 0) {
            Write-Output "There are no deployments older than $($numberOfDaysToKeep) days old in $($resourceGroupName)... skipping"
        }
        else {
            Write-Output "Deleting $($numberOfitemsToRemove.Count) deployment(s) from $($resourceGroupName) as they are more than $($numberOfDaysToKeep) days old."
            $itemsToRemove | ForEach-Object { Write-Output "Deleting $($_.DeploymentName)"; Remove-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -name $_.DeploymentName }
        }
    }

    if ($null -ne $($numberOfDeploymentsToKeep) -and $($numberOfDeploymentsToKeep) -gt 0) {
        $azureDeploymentNameAndDate = Get-Deployments $resourceGroupName

        Write-Output "Found $($azureDeploymentNameAndDate.Count) deployments from the $resourceGroupName resource group"

        $itemsToRemove = $azureDeploymentNameAndDate | Sort-Object Time -Descending | select-object -skip $numberOfDeploymentsToKeep
        $numberOfItemsToRemove = $itemsToRemove | Measure-Object

        if ($numberOfitemsToRemove.Count -eq 0) {
            Write-Output "Max number of deployments set to keep is $numberOfDeploymentsToKeep... skipping"
        }
        else {
            Write-Output "Maximum number of deployments exceeded. Deleting $($numberOfitemsToRemove.Count) deployment(s) from $($resourceGroupName)"
            $itemsToRemove | ForEach-Object { Write-Output "Deleting $($_.DeploymentName)"; Remove-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -name $_.DeploymentName }
        }
    }
}

## --------------------------------------------------------------------------------------
## Input
## --------------------------------------------------------------------------------------

$resourceGroupName = Get-Param 'Azure.RemoveResourceGroupDeployments.ResourceGroupName' -Required
$numberOfDeploymentsToKeep = Get-Param 'Azure.RemoveResourceGroupDeployments.NumberOfDeploymentsToKeep' -Default 0
$numberOfDaysToKeep = Get-Param 'Azure.RemoveResourceGroupDeployments.NumberOfDaysToKeep' -Default 0

Remove-AzureRmResourceDeployments -resourceGroupName $resourceGroupName -numberOfDeploymentsToKeep $numberOfDeploymentsToKeep -numberOfDaysToKeep $numberOfDaysToKeep -Verbose
