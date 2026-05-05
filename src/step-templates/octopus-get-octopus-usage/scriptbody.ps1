$OctopusDeployUrl = $OctopusParameters["GetUsage.Octopus.ServerUri"]
$OctopusDeployApiKey = $OctopusParameters["GetUsage.Octopus.ApiKey"]

## To avoid nuking your instance, this script will pull back 50 items at a time and count them.  It is designed to run on instances as far back as 3.4.

function Get-OctopusUrl
{
    param (
        $EndPoint,
        $SpaceId,
        $OctopusUrl        
    )

    $octopusUrlToUse = $OctopusUrl
    if ($OctopusUrl.EndsWith("/"))
    {
        $octopusUrlToUse = $OctopusUrl.Substring(0, $OctopusUrl.Length - 1)
    }

    if ($EndPoint -match "/api")
    {
        if (!$EndPoint.StartsWith("/api"))
        {
            $EndPoint = $EndPoint.Substring($EndPoint.IndexOf("/api"))
        }

        return "$octopusUrlToUse$EndPoint"
    }

    if ([string]::IsNullOrWhiteSpace($SpaceId))
    {
        return "$octopusUrlToUse/api/$EndPoint"
    }

    return "$octopusUrlToUse/api/$spaceId/$EndPoint"
}

function Invoke-OctopusApi
{
    param
    (
        $endPoint,
        $spaceId,
        $octopusUrl,        
        $apiKey
    )    

    try
    {        
        $url = Get-OctopusUrl -EndPoint $endPoint -SpaceId $spaceId -OctopusUrl $octopusUrl

        Write-Host "Invoking $url"
        return Invoke-RestMethod -Method Get -Uri $url -Headers @{"X-Octopus-ApiKey" = "$apiKey" } -ContentType 'application/json; charset=utf-8' -TimeoutSec 60        
    }
    catch
    {
        Write-Host "There was an error making a Get call to the $url.  Please check that for more information." -ForegroundColor Red

        if ($null -ne $_.Exception.Response)
        {
            if ($_.Exception.Response.StatusCode -eq 401)
            {
                Write-Host "Unauthorized error returned from $url, please verify API key and try again" -ForegroundColor Red
            }
            elseif ($_.ErrorDetails.Message)
            {                
                Write-Host -Message "Error calling $url StatusCode: $($_.Exception.Response) $($_.ErrorDetails.Message)" -ForegroundColor Red
                Write-Host $_.Exception -ForegroundColor Red
            }            
            else 
            {
                Write-Host $_.Exception -ForegroundColor Red
            }
        }
        else
        {
            Write-Host $_.Exception -ForegroundColor Red
        }

        Write-Host "Stopping the script from proceeding" -ForegroundColor Red
        exit 1
    }    
}

function Get-OctopusObjectCount
{
    param
    (
        $endPoint,
        $spaceId,
        $octopusUrl,        
        $apiKey
    )

    $activeItemCount = 0
    $disabledItemCount = 0
    $currentPage = 1
    $pageSize = 50
    $skipValue = 0
    $haveReachedEndOfList = $false

    while ($haveReachedEndOfList -eq $false)
    {
        $currentEndPoint = "$($endPoint)?skip=$skipValue&take=$pageSize"

        $itemList = Invoke-OctopusApi -endPoint $currentEndPoint -spaceId $spaceId -octopusUrl $octopusUrl -apiKey $apiKey

        foreach ($item in $itemList.Items)
        {
            if ($null -ne (Get-Member -InputObject $item -Name "IsDisabled" -MemberType Properties))
            {          
                if ($item.IsDisabled -eq $false)
                {
                    $activeItemCount += 1
                }
                else
                {
                    $disabledItemCount += 1
                }
            }
            else 
            {
                $activeItemCount += 1    
            }
        }

        if ($currentPage -lt $itemList.NumberOfPages)
        {
            $skipValue = $currentPage * $pageSize
            $currentPage += 1

            Write-Host "The endpoint $endpoint has reported there are $($itemList.NumberOfPages) pages.  Setting the skip value to $skipValue and re-querying"
        }
        else
        {
            $haveReachedEndOfList = $true    
        }
    }
    
    return @{
        ActiveItemCount = $activeItemCount
        DisabledItemCount = $disabledItemCount
        TotalItemCount = $activeItemCount + $disabledItemCount
    }
}

function Get-EffectiveLimit 
{
    param (
        $limit
    )

    if ($null -ne (Get-Member -InputObject $limit -Name "LicensedLimit" -MemberType Properties))
    {
        if ($limit.LicensedLimit -eq 2147483647) # int.MaxValue means it is an unlimited license
        {
            return "of Unlimited"
        }
        else
        {
            return "of $($limit.LicensedLimit)"
        }
    }
    
    return ""
}

function Get-OctopusDeploymentTargetsCount
{
    param
    (
        $spaceId,
        $octopusUrl,        
        $apiKey
    )

    $targetCount = @{
        TargetCount = 0 
        ActiveTargetCount = 0
        UnavailableTargetCount = 0        
        DisabledTargets = 0
        ActiveListeningTentacleTargets = 0
        ActivePollingTentacleTargets = 0
        ActiveSshTargets = 0        
        ActiveKubernetesCount = 0
        ActiveAzureWebAppCount = 0
        ActiveAzureServiceFabricCount = 0
        ActiveAzureCloudServiceCount = 0
        ActiveOfflineDropCount = 0    
        ActiveECSClusterCount = 0
        ActiveCloudRegions = 0  
        ActiveFtpTargets = 0
        DisabledListeningTentacleTargets = 0
        DisabledPollingTentacleTargets = 0
        DisabledSshTargets = 0        
        DisabledKubernetesCount = 0
        DisabledAzureWebAppCount = 0
        DisabledAzureServiceFabricCount = 0
        DisabledAzureCloudServiceCount = 0
        DisabledOfflineDropCount = 0    
        DisabledECSClusterCount = 0
        DisabledCloudRegions = 0  
        DisabledFtpTargets = 0            
    }

    $currentPage = 1
    $pageSize = 50
    $skipValue = 0
    $haveReachedEndOfList = $false

    while ($haveReachedEndOfList -eq $false)
    {
        $currentEndPoint = "machines?skip=$skipValue&take=$pageSize"

        $itemList = Invoke-OctopusApi -endPoint $currentEndPoint -spaceId $spaceId -octopusUrl $octopusUrl -apiKey $apiKey

        foreach ($item in $itemList.Items)
        {
            $targetCount.TargetCount += 1

            if ($item.IsDisabled -eq $true)
            {
                $targetCount.DisabledTargets += 1                  

                if ($item.EndPoint.CommunicationStyle -eq "None")
                {
                    $targetCount.DisabledCloudRegions += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "TentacleActive")
                {
                    $targetCount.DisabledPollingTentacleTargets += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "TentaclePassive")
                {
                    $targetCount.DisabledListeningTentacleTargets += 1
                }
                # Cover newer k8s agent and traditional worker-API approach
                elseif ($item.EndPoint.CommunicationStyle -ilike "Kubernetes*")
                {
                    $targetCount.DisabledKubernetesCount += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "AzureWebApp")
                {
                    $targetCount.DisabledAzureWebAppCount += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "Ssh")
                {
                    $targetCount.DisabledSshTargets += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "Ftp")
                {
                    $targetCount.DisabledFtpTargets += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "AzureCloudService")
                {
                    $targetCount.DisabledAzureCloudServiceCount += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "AzureServiceFabricCluster")
                {
                    $targetCount.DisabledAzureServiceFabricCount += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "OfflineDrop")
                {
                    $targetCount.DisabledOfflineDropCount += 1
                }
                else
                {
                    $targetCount.DisabledECSClusterCount += 1
                }
            }
            else
            {
                if ($item.HealthStatus -eq "Healthy" -or $item.HealthStatus -eq "HealthyWithWarnings")
                {
                    $targetCount.ActiveTargetCount += 1
                }
                else
                {
                    $targetCount.UnavailableTargetCount += 1    
                }

                if ($item.EndPoint.CommunicationStyle -eq "None")
                {
                    $targetCount.ActiveCloudRegions += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "TentacleActive")
                {
                    $targetCount.ActivePollingTentacleTargets += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "TentaclePassive")
                {
                    $targetCount.ActiveListeningTentacleTargets += 1
                }
                # Cover newer k8s agent and traditional worker-API approach
                elseif ($item.EndPoint.CommunicationStyle -ilike "Kubernetes*")
                {
                    $targetCount.ActiveKubernetesCount += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "AzureWebApp")
                {
                    $targetCount.ActiveAzureWebAppCount += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "Ssh")
                {
                    $targetCount.ActiveSshTargets += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "Ftp")
                {
                    $targetCount.ActiveFtpTargets += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "AzureCloudService")
                {
                    $targetCount.ActiveAzureCloudServiceCount += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "AzureServiceFabricCluster")
                {
                    $targetCount.ActiveAzureServiceFabricCount += 1
                }
                elseif ($item.EndPoint.CommunicationStyle -eq "OfflineDrop")
                {
                    $targetCount.ActiveOfflineDropCount += 1
                }
                else
                {
                    $targetCount.ActiveECSClusterCount += 1
                }
            }                                
        }

        if ($currentPage -lt $itemList.NumberOfPages)
        {
            $skipValue = $currentPage * $pageSize
            $currentPage += 1

            Write-Host "The endpoint $endpoint has reported there are $($itemList.NumberOfPages) pages.  Setting the skip value to $skipValue and re-querying"
        }
        else
        {
            $haveReachedEndOfList = $true    
        }
    }
    
    return $targetCount
}

# Add support for both TLS 1.2 and TLS 1.3
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13

$ObjectCounts = @{
    TotalProjectCount = 0
    ActiveProjectCount = 0
    DisabledProjectCount = 0
    TotalTenantCount = 0        
    ActiveTenantCount = 0
    DisabledTenantCount = 0
    TargetCount = 0 
    DisabledTargets = 0
    ActiveTargetCount = 0
    UnavailableTargetCount = 0
    ActiveListeningTentacleTargets = 0
    ActivePollingTentacleTargets = 0
    ActiveSshTargets = 0        
    ActiveKubernetesCount = 0
    ActiveAzureWebAppCount = 0
    ActiveAzureServiceFabricCount = 0
    ActiveAzureCloudServiceCount = 0
    ActiveOfflineDropCount = 0    
    ActiveECSClusterCount = 0
    ActiveCloudRegions = 0
    ActiveFtpTargets = 0 
    DisabledListeningTentacleTargets = 0
    DisabledPollingTentacleTargets = 0
    DisabledSshTargets = 0        
    DisabledKubernetesCount = 0
    DisabledAzureWebAppCount = 0
    DisabledAzureServiceFabricCount = 0
    DisabledAzureCloudServiceCount = 0
    DisabledOfflineDropCount = 0    
    DisabledECSClusterCount = 0
    DisabledCloudRegions = 0  
    DisabledFtpTargets = 0             
    WorkerCount = 0
    ListeningTentacleWorkers = 0
    PollingTentacleWorkers = 0
    SshWorkers = 0
    ActiveWorkerCount = 0
    UnavailableWorkerCount = 0
    WindowsLinuxMachineCount = 0
    LicensedTargetCount = $null
    LicensedTargetEntitlement = $null
    LicensedWorkerCount = 0
    LicensedWorkerEntitlement = $null
    LicensedUserCount = 0
    LicensedUserEntitlement = $null    
    LicensedProjectCount = 0
    LicensedProjectEntitlement = $null
    LicensedTenantCount = $null
    LicensedTenantEntitlement = $null
    LicensedMachineCount = $null
    LicensedMachineEntitlement = $null
}

Write-Host "Getting Octopus Deploy Version Information"
$apiInformation = Invoke-OctopusApi -endPoint "/api" -spaceId $null -octopusUrl $OctopusDeployUrl -apiKey $OctopusDeployApiKey
$splitVersion = $apiInformation.Version -split "\."
$OctopusMajorVersion = [int]$splitVersion[0]
$OctopusMinorVersion = [int]$splitVersion[1]
$isPtm = $false

$hasLicenseSummary = $OctopusMajorVersion -ge 4
$hasSpaces = $OctopusMajorVersion -ge 2019
$hasWorkers = ($OctopusMajorVersion -eq 2018 -and $OctopusMinorVersion -ge 7) -or $OctopusMajorVersion -ge 2019

$spaceIdList = @()
if ($hasSpaces -eq $true)
{
    $OctopusSpaceList = Invoke-OctopusApi -endPoint "spaces?skip=0&take=10000" -octopusUrl $OctopusDeployUrl -spaceId $null -apiKey $OctopusDeployApiKey
    foreach ($space in $OctopusSpaceList.Items)
    {
        $spaceIdList += $space.Id
    }
}
else
{
    $spaceIdList += $null    
}

if ($hasLicenseSummary -eq $true)
{
    Write-Host "Checking the license summary for this instance"
    $licenseSummary = Invoke-OctopusApi -endPoint "licenses/licenses-current-status" -octopusUrl $OctopusDeployUrl -spaceId $null -apiKey $OctopusDeployApiKey

    if ($null -eq (Get-Member -InputObject $licenseSummary -Name "IsPtm" -MemberType Properties))
    {
        $isPtm = $false
    }
    elseif($licenseSummary.IsPtm -eq $true)
    {
        $isPtm = $true
    }
    else
    {
        $isPtm = $false
    }

    if ($null -ne (Get-Member -InputObject $licenseSummary -Name "NumberOfMachines" -MemberType Properties))
    {
        $ObjectCounts.LicensedTargetCount = $licenseSummary.NumberOfMachines
    }
    else
    {
        foreach ($limit in $licenseSummary.Limits)
        {
            if ($limit.Name -eq "Projects")
            {
                Write-Host "Your instance is currently using $($limit.CurrentUsage) Projects"
                $ObjectCounts.LicensedProjectCount = $limit.CurrentUsage
                $objectCounts.LicensedProjectEntitlement = Get-EffectiveLimit $limit
            }

            if ($limit.Name -eq "Tenants")
            {
                Write-Host "Your instance is currently using $($limit.CurrentUsage) Tenants"
                $ObjectCounts.LicensedTenantCount = $limit.CurrentUsage
                $objectCounts.LicensedTenantEntitlement = Get-EffectiveLimit $limit
            }

            if ($limit.Name -eq "Targets")
            {
                if ($isPtm -eq $true)
                {                
                    Write-Host "Your instance is currently using $($limit.CurrentUsage) Machines"
                    $ObjectCounts.LicensedMachineCount = $limit.CurrentUsage
                    $objectCounts.LicensedMachineEntitlement = Get-EffectiveLimit $limit
                }
                else
                {
                    Write-Host "Your instance is currently using $($limit.CurrentUsage) Targets"
                    $ObjectCounts.LicensedTargetCount = $limit.CurrentUsage
                    $objectCounts.LicensedTargetEntitlement = Get-EffectiveLimit $limit
                }                
            }

            if ($limit.Name -eq "Workers")
            {
                Write-Host "Your instance is currently using $($limit.CurrentUsage) Workers"
                $ObjectCounts.LicensedWorkerCount = $limit.CurrentUsage
                $objectCounts.LicensedWorkerEntitlement = Get-EffectiveLimit $limit
            }

            if ($limit.Name -eq "Users")
            {
                Write-Host "Your instance is currently using $($limit.CurrentUsage) Users"
                $ObjectCounts.LicensedUserCount = $limit.CurrentUsage
                $objectCounts.LicensedUserEntitlement = Get-EffectiveLimit $limit
            }            
        }
    }
}


foreach ($spaceId in $spaceIdList)
{    
    Write-Host "Getting project counts for $spaceId"
    $projectCounts = Get-OctopusObjectCount -endPoint "projects" -spaceId $spaceId -octopusUrl $OctopusDeployUrl -apiKey $OctopusDeployApiKey

    Write-Host "$spaceId has $($projectCounts.ActiveItemCount) active projects."
    $ObjectCounts.ActiveProjectCount += $projectCounts.ActiveItemCount

    Write-Host "$spaceId has $($projectCounts.DisabledItemCount) disabled projects."
    $ObjectCounts.DisabledProjectCount += $projectCounts.DisabledItemCount

    Write-Host "$spaceId has $($projectCounts.TotalItemCount) total projects."
    $ObjectCounts.TotalProjectCount += $projectCounts.TotalItemCount

    Write-Host "Getting tenant counts for $spaceId"
    $tenantCounts = Get-OctopusObjectCount -endPoint "tenants" -spaceId $spaceId -octopusUrl $OctopusDeployUrl -apiKey $OctopusDeployApiKey

    Write-Host "$spaceId has $($tenantCounts.ActiveItemCount) active tenants."
    $ObjectCounts.ActiveTenantCount += $tenantCounts.ActiveItemCount

    Write-Host "$spaceId has $($tenantCounts.InactiveItemCount) disabled tenants."
    $ObjectCounts.DisabledTenantCount += $tenantCounts.DisabledItemCount

    Write-Host "$spaceId has $($tenantCounts.TotalItemCount) total tenants."
    $ObjectCounts.TotalTenantCount += $tenantCounts.TotalItemCount
    
    Write-Host "Getting Infrastructure Summary for $spaceId"
    $infrastructureSummary = Get-OctopusDeploymentTargetsCount -spaceId $spaceId -octopusUrl $OctopusDeployUrl -apiKey $OctopusDeployApiKey

    Write-host "$spaceId has $($infrastructureSummary.TargetCount) targets"
    $ObjectCounts.TargetCount += $infrastructureSummary.TargetCount

    Write-Host "$spaceId has $($infrastructureSummary.ActiveTargetCount) Healthy Targets"
    $ObjectCounts.ActiveTargetCount += $infrastructureSummary.ActiveTargetCount

    Write-Host "$spaceId has $($infrastructureSummary.DisabledTargets) Disabled Targets"
    $ObjectCounts.DisabledTargets += $infrastructureSummary.DisabledTargets

    Write-Host "$spaceId has $($infrastructureSummary.UnavailableTargetCount) Unhealthy Targets"
    $ObjectCounts.UnavailableTargetCount += $infrastructureSummary.UnavailableTargetCount    

    Write-host "$spaceId has $($infrastructureSummary.ActiveListeningTentacleTargets) Active Listening Tentacles Targets"
    $ObjectCounts.ActiveListeningTentacleTargets += $infrastructureSummary.ActiveListeningTentacleTargets

    Write-host "$spaceId has $($infrastructureSummary.ActivePollingTentacleTargets) Active Polling Tentacles Targets"
    $ObjectCounts.ActivePollingTentacleTargets += $infrastructureSummary.ActivePollingTentacleTargets

    Write-host "$spaceId has $($infrastructureSummary.ActiveCloudRegions) Active Cloud Region Targets"
    $ObjectCounts.ActiveCloudRegions += $infrastructureSummary.ActiveCloudRegions

    Write-host "$spaceId has $($infrastructureSummary.ActiveOfflineDropCount) Active Offline Packages"
    $ObjectCounts.ActiveOfflineDropCount += $infrastructureSummary.ActiveOfflineDropCount

    Write-host "$spaceId has $($infrastructureSummary.ActiveSshTargets) Active SSH Targets"
    $ObjectCounts.ActiveSshTargets += $infrastructureSummary.ActiveSshTargets

    Write-host "$spaceId has $($infrastructureSummary.ActiveSshTargets) Active Kubernetes Targets"
    $ObjectCounts.ActiveKubernetesCount += $infrastructureSummary.ActiveKubernetesCount

    Write-host "$spaceId has $($infrastructureSummary.ActiveAzureWebAppCount) Active Azure Web App Targets"
    $ObjectCounts.ActiveAzureWebAppCount += $infrastructureSummary.ActiveAzureWebAppCount

    Write-host "$spaceId has $($infrastructureSummary.ActiveAzureServiceFabricCount) Active Azure Service Fabric Cluster Targets"
    $ObjectCounts.ActiveAzureServiceFabricCount += $infrastructureSummary.ActiveAzureServiceFabricCount

    Write-host "$spaceId has $($infrastructureSummary.ActiveAzureCloudServiceCount) Active (Legacy) Azure Cloud Service Targets"
    $ObjectCounts.ActiveAzureCloudServiceCount += $infrastructureSummary.ActiveAzureCloudServiceCount

    Write-host "$spaceId has $($infrastructureSummary.ActiveECSClusterCount) Active ECS Cluster Targets"
    $ObjectCounts.ActiveECSClusterCount += $infrastructureSummary.ActiveECSClusterCount

    Write-host "$spaceId has $($infrastructureSummary.ActiveFtpTargets) Active FTP Targets"
    $ObjectCounts.ActiveFtpTargets += $infrastructureSummary.ActiveFtpTargets

    Write-host "$spaceId has $($infrastructureSummary.DisabledListeningTentacleTargets) Disabled Listening Tentacles Targets"
    $ObjectCounts.DisabledListeningTentacleTargets += $infrastructureSummary.DisabledListeningTentacleTargets

    Write-host "$spaceId has $($infrastructureSummary.DisabledPollingTentacleTargets) Disabled Polling Tentacles Targets"
    $ObjectCounts.DisabledPollingTentacleTargets += $infrastructureSummary.DisabledPollingTentacleTargets

    Write-host "$spaceId has $($infrastructureSummary.DisabledCloudRegions) Disabled Cloud Region Targets"
    $ObjectCounts.DisabledCloudRegions += $infrastructureSummary.DisabledCloudRegions

    Write-host "$spaceId has $($infrastructureSummary.DisabledOfflineDropCount) Disabled Offline Packages"
    $ObjectCounts.DisabledOfflineDropCount += $infrastructureSummary.DisabledOfflineDropCount

    Write-host "$spaceId has $($infrastructureSummary.DisabledSshTargets) Disabled SSH Targets"
    $ObjectCounts.DisabledSshTargets += $infrastructureSummary.DisabledSshTargets

    Write-host "$spaceId has $($infrastructureSummary.ActiveSshTargets) Disabled Kubernetes Targets"
    $ObjectCounts.DisabledKubernetesCount += $infrastructureSummary.DisabledKubernetesCount

    Write-host "$spaceId has $($infrastructureSummary.DisabledAzureWebAppCount) Disabled Azure Web App Targets"
    $ObjectCounts.DisabledAzureWebAppCount += $infrastructureSummary.DisabledAzureWebAppCount

    Write-host "$spaceId has $($infrastructureSummary.DisabledAzureServiceFabricCount) Disabled Azure Service Fabric Cluster Targets"
    $ObjectCounts.DisabledAzureServiceFabricCount += $infrastructureSummary.DisabledAzureServiceFabricCount

    Write-host "$spaceId has $($infrastructureSummary.DisabledAzureCloudServiceCount) Disabled (Legacy) Azure Cloud Service Targets"
    $ObjectCounts.DisabledAzureCloudServiceCount += $infrastructureSummary.DisabledAzureCloudServiceCount

    Write-host "$spaceId has $($infrastructureSummary.DisabledECSClusterCount) Disabled ECS Cluster Targets"
    $ObjectCounts.DisabledECSClusterCount += $infrastructureSummary.DisabledECSClusterCount

    Write-host "$spaceId has $($infrastructureSummary.DisabledFtpTargets) Disabled FTP Targets"
    $ObjectCounts.DisabledFtpTargets += $infrastructureSummary.DisabledFtpTargets

    if ($hasWorkers -eq $true)
    {
        Write-Host "Getting worker information for $spaceId"
        $workerPoolSummary = Invoke-OctopusApi -endPoint "workerpools/summary" -spaceId $spaceId -octopusUrl $OctopusDeployUrl -apiKey $OctopusDeployApiKey 

        Write-host "$spaceId has $($workerPoolSummary.TotalMachines) Workers"
        $ObjectCounts.WorkerCount += $workerPoolSummary.TotalMachines

        Write-Host "$spaceId has $($workerPoolSummary.MachineHealthStatusSummaries.Healthy) Healthy Workers"
        $ObjectCounts.ActiveWorkerCount += $workerPoolSummary.MachineHealthStatusSummaries.Healthy
    
        Write-Host "$spaceId has $($workerPoolSummary.MachineHealthStatusSummaries.HasWarnings) Healthy with Warning Workers"
        $ObjectCounts.ActiveWorkerCount += $workerPoolSummary.MachineHealthStatusSummaries.HasWarnings
    
        Write-Host "$spaceId has $($workerPoolSummary.MachineHealthStatusSummaries.Unhealthy) Unhealthy Workers"
        $ObjectCounts.UnavailableWorkerCount += $workerPoolSummary.MachineHealthStatusSummaries.Unhealthy
    
        Write-Host "$spaceId has $($workerPoolSummary.MachineHealthStatusSummaries.Unknown) Workers with a Status of Unknown"
        $ObjectCounts.UnavailableWorkerCount += $workerPoolSummary.MachineHealthStatusSummaries.Unknown
        
        Write-host "$spaceId has $($workerPoolSummary.MachineEndpointSummaries.TentaclePassive) Listening Tentacles Workers"
        $ObjectCounts.ListeningTentacleWorkers += $workerPoolSummary.MachineEndpointSummaries.TentaclePassive

        Write-host "$spaceId has $($workerPoolSummary.MachineEndpointSummaries.TentacleActive) Polling Tentacles Workers"
        $ObjectCounts.PollingTentacleWorkers += $workerPoolSummary.MachineEndpointSummaries.TentacleActive        

        if ($null -ne (Get-Member -InputObject $workerPoolSummary.MachineEndpointSummaries -Name "Ssh" -MemberType Properties))
        {
            Write-host "$spaceId has $($workerPoolSummary.MachineEndpointSummaries.TentacleActive) SSH Targets Workers"
            $ObjectCounts.SshWorkers += $workerPoolSummary.MachineEndpointSummaries.Ssh
        }
    }
}

Write-Host "Calculating Windows and Linux Machine Count"
$ObjectCounts.WindowsLinuxMachineCount = $ObjectCounts.ActivePollingTentacleTargets + $ObjectCounts.ActiveListeningTentacleTargets + $ObjectCounts.ActiveSshTargets

if ($hasLicenseSummary -eq $false)
{
    $ObjectCounts.LicensedTargetCount = $ObjectCounts.TargetCount - $ObjectCounts.ActiveCloudRegions - $ObjectCounts.DisabledTargets    
}

# Get node information
$nodeInfo = Invoke-OctopusApi -endPoint "octopusservernodes" -octopusUrl $OctopusDeployUrl -spaceId $null -apiKey $OctopusDeployApiKey
      
$text = @"
The item counts are as follows:
`tInstance ID: $($apiInformation.InstallationId)
`tServer Version: $($apiInformation.Version)
`tNumber of Server Nodes: $($nodeInfo.TotalResults)
`tEntitlement Usage
$(if ($isPtm) {
"`t`tLicensed Project Count: $($ObjectCounts.LicensedProjectCount) $($ObjectCounts.LicensedProjectEntitlement)
`t`tLicensed Tenant Count: $($ObjectCounts.LicensedTenantCount) $($ObjectCounts.LicensedTenantEntitlement)
`t`tLicensed Machine Count: $($ObjectCounts.LicensedMachineCount) $($ObjectCounts.LicensedMachineEntitlement)"
} else {
"`t`tLicensed Target Count: $($ObjectCounts.LicensedTargetCount) $($ObjectCounts.LicensedTargetEntitlement)"
})
`t`tLicensed User Count: $($ObjectCounts.LicensedUserCount) $($ObjectCounts.LicensedUserEntitlement)
`t`tLicensed Worker Count: $($ObjectCounts.LicensedWorkerCount) $($ObjectCounts.LicensedWorkerEntitlement)
`tProject Count: $($ObjectCounts.TotalProjectCount)
`t`tActive Project Count (Counted against entitlements for all licenses): $($ObjectCounts.ActiveProjectCount)
`t`tDisabled Project Count (Counted against entitlements for free licenses): $($ObjectCounts.DisabledProjectCount)
`tTenant Count: $($ObjectCounts.TotalTenantCount)
`t`tActive Tenant Count (Counted against entitlements for all licenses): $($ObjectCounts.ActiveTenantCount)
`t`tDisabled Tenant Count (Counted against entitlements for free licenses): $($ObjectCounts.DisabledTenantCount)
`tMachine Counts (Active Linux and Windows Tentacles and SSH Connections): $($ObjectCounts.WindowsLinuxMachineCount)
`tDeployment Target Count: $($ObjectCounts.TargetCount)
`t`tActive and Available Targets: $($ObjectCounts.ActiveTargetCount)
`t`tActive but Unavailable Targets: $($ObjectCounts.UnavailableTargetCount)
`t`tActive Target Breakdown
`t`t`tListening Tentacle Target Count: $($ObjectCounts.ActiveListeningTentacleTargets)
`t`t`tPolling Tentacle Target Count: $($ObjectCounts.ActivePollingTentacleTargets)
`t`t`tSSH Target Count: $($ObjectCounts.ActiveSshTargets)
`t`t`tKubernetes Target Count: $($ObjectCounts.ActiveKubernetesCount)
`t`t`tAzure Web App Target Count: $($ObjectCounts.ActiveAzureWebAppCount)
`t`t`tAzure Service Fabric Cluster Target Count: $($ObjectCounts.ActiveAzureServiceFabricCount)
`t`t`tAzure (Legacy) Cloud Service Target Count: $($ObjectCounts.ActiveAzureCloudServiceCount)
`t`t`tAWS ECS Cluster Target Count: $($ObjectCounts.ActiveECSClusterCount)
`t`t`tOffline Target Count: $($ObjectCounts.ActiveOfflineDropCount)
`t`t`tCloud Region Target Count: $($ObjectCounts.ActiveCloudRegions)
`t`t`tFtp Target Count: $($ObjectCounts.ActiveFtpTargets)
`t`tDisabled Targets Targets: $($ObjectCounts.DisabledTargets)
`t`tDisabled Target Breakdown
`t`t`tListening Tentacle Target Count: $($ObjectCounts.DisabledListeningTentacleTargets)
`t`t`tPolling Tentacle Target Count: $($ObjectCounts.DisabledPollingTentacleTargets)
`t`t`tSSH Target Count: $($ObjectCounts.DisabledSshTargets)
`t`t`tKubernetes Target Count: $($ObjectCounts.DisabledKubernetesCount)
`t`t`tAzure Web App Target Count: $($ObjectCounts.DisabledAzureWebAppCount)
`t`t`tAzure Service Fabric Cluster Target Count: $($ObjectCounts.DisabledAzureServiceFabricCount)
`t`t`tAzure (Legacy) Cloud Service Target Count: $($ObjectCounts.DisabledAzureCloudServiceCount)
`t`t`tAWS ECS Cluster Target Count: $($ObjectCounts.DisabledECSClusterCount)
`t`t`tOffline Target Count: $($ObjectCounts.DisabledOfflineDropCount)
`t`t`tCloud Region Target Count: $($ObjectCounts.DisabledCloudRegions)
`t`t`tFtp Target Count: $($ObjectCounts.DisabledFtpTargets)
`tWorker Count: $($ObjectCounts.WorkerCount)
`t`tActive Workers: $($ObjectCounts.ActiveWorkerCount)
`t`tUnavailable Workers: $($ObjectCounts.UnavailableWorkerCount)
`t`tWorker Breakdown
`t`t`tListening Tentacle Target Count: $($ObjectCounts.ListeningTentacleWorkers)
`t`t`tPolling Tentacle Target Count: $($ObjectCounts.PollingTentacleWorkers)
`t`t`tSSH Target Count: $($ObjectCounts.SshWorkers)
"@

Write-Host $text
$text > octopus-usage.txt
New-OctopusArtifact "$($PWD)/octopus-usage.txt"