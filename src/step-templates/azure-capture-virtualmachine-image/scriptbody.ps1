<#
 ----- Capture AzureRM Virtual Machine Image ----- 
    Paul Marston @paulmarsy (paul@marston.me)
Links
    https://github.com/OctopusDeploy/Library/commits/master/step-templates/azure-capture-virtualmachine-image.json
    
The sequence of steps performed by the step template:
    1) Virtual Machine prep
        a) PowerState/running - Custom script extension is used to sysprep & shutdown
        b) PowerState/stopped - only when the VM is shutdown by the OS, if Azure stops the VM it is automatically deallocated
        c) PowerState/deallocated
        d) OSState/generalized
    2) Image capture
        - Managed VM & Managed Image - New image with VM as source
        - Managed VM & Unmanaged VHD - Access to the underlying blob is granted, and the VHD copied into the specified storage account
        - Unmanaged VM & Managed Image - New image with VM as source
        - Unmanaged VM & Unmanaged VHD - VM image is saved, a SAS token is generated and it is copied from the VM's storage account into the specified storage account
    3) Virtual machine cleanup.
        Once a VM has been marked as 'generalized' Azure will no longer allow it to be started up, making the VM unusable
        If the delete option is selected, and the image just created has been moved outside the VM's resource group 
        
----- Advanced Configuration Settings -----
Variable names can use either of the following two formats: 
    Octopus.Action.<Setting Name> - will apply to all steps in the deployment, e.g.
        Octopus.Action.DebugLogging
    Octopus.Action[Step Name].<Setting Name> - will apply to 'step name' alone, e.g.
        Octopus.Action[Capture Web VM Image].StorageAccountKey

Available Settings:
    VhdDestContainer - overrides the default container that an unmanaged VHD image is copied to, default is 'images'
    StorageAccountKey - allows copying to a storage account in a different subscription by using the providing the key, default is null
#>
#Requires -Modules AzureRM.Resources
#Requires -Modules AzureRM.Compute
#Requires -Modules AzureRM.Storage
#Requires -Modules Azure.Storage

$ErrorActionPreference = 'Stop'

<#---------- SysPrep Script - Begin  ----------#>
<#
    Sysprep marker file: C:\WindowsAzure\sysprep
    1) If marker file exists, sysprep has already been run so exit script
    2) Start a new powershell process and exit with code 0, this allows the custom script extension to report back as having run successfully to Azure
        a) In the child script wait until the successful exit code has been logged
        b) Create the marker file
        c) Run sysprep
#>
$SysPrepScript = @'
if (Test-Path "${env:SystemDrive}\WindowsAzure\sysprep") { return }

Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NonInteractive','-NoProfile',('-EncodedCommand {0}' -f ([System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes({
    do {
        Start-Sleep -Seconds 1
        $status = Get-ChildItem "${env:SystemDrive}\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\*\Status\" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content | ConvertFrom-Json
    } while ($status[0].status.code -ne 0)
    New-Item -ItemType File -Path "${env:SystemDrive}\WindowsAzure\sysprep" -Force | Out-Null
    & (Join-Path -Resolve ([System.Environment]::SystemDirectory) 'sysprep\sysprep.exe') /oobe /generalize /quiet /shutdown
}.ToString())))))

exit 0
'@
<#---------- SysPrep Script - End ----------#>

function Get-OctopusSetting {
    param([Parameter(Position = 0, Mandatory)][string]$Name, [Parameter(Position = 1)]$DefaultValue)
    $formattedName = 'Octopus.Action.{0}' -f $Name
    if ($OctopusParameters.ContainsKey($formattedName)) {
        $value = $OctopusParameters[$formattedName]
        if ($DefaultValue -is [int]) { return ([int]::Parse($value)) }
        if ($DefaultValue -is [bool]) { return ([System.Convert]::ToBoolean($value)) }
        if ($DefaultValue -is [array] -or $DefaultValue -is [hashtable] -or $DefaultValue -is [pscustomobject]) { return (ConvertFrom-Json -InputObject $value) }
        return $value
    }
    else { return $DefaultValue }
}
function Test-String {
    param([Parameter(Position=0)]$InputObject,[switch]$ForAbsence)

    $hasNoValue = [System.String]::IsNullOrWhiteSpace($InputObject)
    if ($ForAbsence) { $hasNoValue }
    else { -not $hasNoValue }
}
filter Out-Verbose {
    Write-Verbose ($_ | Out-String)
}
function Split-BlobUri {
    param($Uri)
    $uriRegex = [regex]::Match($Uri, '(?>https:\/\/)(?<Account>[a-z0-9]{3,24})\.blob\.core\.windows\.net\/(?<Container>[-a-z0-9]{3,63})\/(?<Blob>.+)')
    if (!$uriRegex.Success) {
        throw "Unable to parse blob uri: $Uri"
    }
    [pscustomobject]@{
        Account = $uriRegex.Groups['Account'].Value
        Container = $uriRegex.Groups['Container'].Value
        Blob = $uriRegex.Groups['Blob'].Value
    }
}
function Get-AzureRmAccessToken {
    # https://github.com/paulmarsy/AzureRest/blob/master/Internals/Get-AzureRmAccessToken.ps1
    $accessToken = Invoke-RestMethod -UseBasicParsing -Uri ('https://login.microsoftonline.com/{0}/oauth2/token?api-version=1.0' -f $OctopusAzureADTenantId) -Method Post -Body @{"grant_type" = "client_credentials"; "resource" = "https://management.core.windows.net/"; "client_id" = $OctopusAzureADClientId; "client_secret" = $OctopusAzureADPassword }
    [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $accessToken.access_token).ToString()
}
function Get-TemporarySasBlob {
    param($BlobName)
    # https://github.com/paulmarsy/AzureRest/blob/master/Exported/New-AzureBlob.ps1
    $sasToken = Invoke-RestMethod -UseBasicParsing -Uri 'https://mscompute2.iaas.ext.azure.com/api/Compute/VmExtensions/GetTemporarySas/' -Headers @{
        [Microsoft.WindowsAzure.Commands.Common.ApiConstants]::AuthorizationHeaderName = (Get-AzureRmAccessToken)
    }
    $containerSas = [uri]::new($sasToken)
    $container = [Microsoft.WindowsAzure.Storage.Blob.CloudBlobContainer]::new($containerSas)
    $blobRef = $container.GetBlockBlobReference($BlobName)
    
    [psobject]@{
        Blob = $blobRef
        Uri = [uri]::new($blobRef.Uri.AbsoluteUri + $containerSas.Query)
    }
}

'Checking AzureRM Modules...' | Out-Verbose
Get-Module | ? Name -like 'AzureRM.*' | Format-Table -AutoSize -Property Name,Version | Out-String | Out-Verbose
if ((Get-Module AzureRM.Compute | % Version) -lt '2.6.0') {
    $bundledErrorMessage = if ([System.Convert]::ToBoolean($OctopusUseBundledAzureModules)) {
        'The Azure PowerShell Modules bundled with Octopus have been loaded. To use the version installed on the server create a variable named "Octopus.Action.Azure.UseBundledAzurePowerShellModules" and set its value to "False".'
    }
    throw "${bundledErrorMessage}Please ensure version 2.6.0 or newer of the AzureRM.Compute module has been installed. The module can be installed with the PowerShell command: Install-Module AzureRM.Compute -MinimumVersion 2.6.0"
}

$vm = Get-AzureRmVM -ResourceGroupName $StepTemplate_ResourceGroupName -Name $StepTemplate_VMName -WarningAction SilentlyContinue
if ($null -eq $vm) {
    throw "Unable to find virtual machine '$StepTemplate_VMName' in resource group '$StepTemplate_ResourceGroupName'"
}
Write-Host "Image will be captured from Virtual Machine '$($vm.Name)' in resource group '$($vm.ResourceGroupName)'"
if (Test-String $StepTemplate_ImageDest -ForAbsence) {
    throw "The Image Destination parameter is required"
}
$StepTemplate_ImageStorageContext = if ($StepTemplate_ImageType -eq 'unmanaged') {
    $storageAccountKey = Get-OctopusSetting StorageAccountKey $null
    if (Test-String $storageAccountKey) {
        Write-Host "Image will be copied to storage account context '$StepTemplate_ImageDest' using provided key"
        New-AzureStorageContext -StorageAccountName $StepTemplate_ImageDest -StorageAccountKey $storageAccountKey
    } else {
        $storageAccountResource = Find-AzureRmResource -ResourceNameEquals $StepTemplate_ImageDest -ResourceType Microsoft.Storage/storageAccounts
        if ($storageAccountResource) {
            Write-Host "Image will be copied to storage account '$($storageAccountResource.Name)' found in resource group '$($storageAccountResource.ResourceGroupName)'"
        } else {
            throw "Unable to find storage account '$StepTemplate_ImageDest'"
        }
        Get-AzureRmStorageAccount -ResourceGroupName $storageAccountResource.ResourceGroupName -Name $storageAccountResource.Name | % Context
    }
}
$StepTemplate_ImageResourceGroupName = switch ($StepTemplate_ImageType) {
    'managed' {
        $resourceGroup = Get-AzureRmResourceGroup -Name $StepTemplate_ImageDest | % ResourceGroupName 
        Write-Host "Managed Image will be created in resource group '$resourceGroup'"
        $resourceGroup
    }
    'unmanaged' { Find-AzureRmResource -ResourceNameEquals $StepTemplate_ImageDest -ResourceType Microsoft.Storage/storageAccounts | % ResourceGroupName }
}
if ($StepTemplate_ImageResourceGroupName -ieq $StepTemplate_ResourceGroupName -and $StepTemplate_DeleteVMResourceGroup -ieq 'True') {
    throw "You have chosen to delete the virtual machine and it's resource group ($StepTemplate_ResourceGroupName), however this resource group is also where the captured image will be created!"
}

Write-Host ('-'*80)
Write-Host "Preparing virtual machine $($vm.Name) for image capture..."

$sysprepRun = $false
while ($true) {
    $statusCode = Get-AzureRmVM -ResourceGroupName $StepTemplate_ResourceGroupName -Name $StepTemplate_VMName -Status -WarningAction SilentlyContinue | % Statuses | % Code
    if ($statusCode -contains 'OSState/generalized') {
        Write-Host 'VM is deallocated & generalized, proceeding to image capture...'
        break
    }
    if ($statusCode -contains 'PowerState/deallocated') {
        Write-Host 'VM has been deallocated, setting state to generalized... '
        Set-AzureRmVM -ResourceGroupName $StepTemplate_ResourceGroupName -Name $StepTemplate_VMName -Generalized | Out-Verbose
        continue
    }
    if ($statusCode -contains 'PowerState/deallocating') {
        Write-Host 'VM is deallocating, waiting...'
        Start-Sleep 30
        continue
    }
    if ($statusCode -contains 'PowerState/stopped') {
        Write-Host 'VM has been shutdown, starting deallocation...'
        Stop-AzureRmVm -ResourceGroupName $StepTemplate_ResourceGroupName -Name $StepTemplate_VMName -Force | Out-Verbose
        continue
    }
    if ($statusCode -contains 'PowerState/stopping') {
        Write-Host 'VM is stopping, waiting...'
        Start-Sleep 30
        continue
    }
    if ($statusCode -contains 'PowerState/running' -and $sysprepRun) {
        Write-Host 'VM is running, but sysprep already deployed, waiting...'
        Start-Sleep 30
        continue
    }
    if ($statusCode -contains 'PowerState/running') {
        Write-Host 'VM is running, performing sysprep...'
        $existingCustomScriptExtensionName = $vm.Extensions | ? VirtualMachineExtensionType -eq 'CustomScriptExtension' | % Name
        if ($existingCustomScriptExtensionName) {
            Write-Warning "Removing existing CustomScriptExtension ($existingCustomScriptExtensionName)..."
            Remove-AzureRmVMCustomScriptExtension -ResourceGroupName $StepTemplate_ResourceGroupName -VMName $StepTemplate_VMName -Name $existingCustomScriptExtensionName -Force | Out-Verbose
        }
        
        Write-Host 'Uploading sysprep script to blob storage...'
        $sysprepScriptFileName = 'Sysprep.ps1'
        $sysprepScriptBlob = Get-TemporarySasBlob $sysprepScriptFileName
        $sysprepScriptBlob.Blob.UploadText($SysPrepScript)
    
        Write-Host 'Deploying sysprep custom script extension...'
        Set-AzureRmVMCustomScriptExtension -ResourceGroupName $StepTemplate_ResourceGroupName -VMName $StepTemplate_VMName -Name 'Sysprep' -Location $vm.Location -FileUri $sysprepScriptBlob.Uri -Run $sysprepScriptFileName -ForceRerun (Get-Date).Ticks | Out-Verbose
        $sysprepRun = $true
        continue
    }
    Write-Warning "VM is in an unknown state. Current status codes: $($statusCode -join ', '). Waiting..."
    Start-Sleep -Seconds 30
}

Write-Host ('-'*80)

Write-Host 'Retrieving virtual machine disk configuration...'
$vm = Get-AzureRmVM -ResourceGroupName $StepTemplate_ResourceGroupName -Name $StepTemplate_VMName -WarningAction SilentlyContinue 
$isManagedVm = $null -ne $vm.StorageProfile.OsDisk.ManagedDisk
if ($isManagedVm) { Write-Host "Virtual machine $($vm.Name) is using Managed Disks" }
$isUnmanagedVm = $null -ne $vm.StorageProfile.OsDisk.Vhd
if ($isUnmanagedVm) { Write-Host "Virtual machine $($vm.Name) is using unmanaged storage account VHDs" }

if ($StepTemplate_ImageType -eq 'managed') {
    Write-Host "Creating Managed Image of $($vm.Name)..."
    $image = New-AzureRmImageConfig -Location $vm.Location -SourceVirtualMachineId $vm.Id
    New-AzureRmImage -Image $image -ImageName $StepTemplate_ImageName -ResourceGroupName $StepTemplate_ImageResourceGroupName | Out-Verbose
    Write-Host 'Image created:'
    Get-AzureRmImage -ImageName $StepTemplate_ImageName -ResourceGroupName $StepTemplate_ImageResourceGroupName | Out-Host
}

if ($StepTemplate_ImageType -eq 'unmanaged') {
    if ($isManagedVm) {
        Write-Host "Granting access to os disk ($($vm.StorageProfile.OsDisk.Name)) blob..."
        $manageDisk = Grant-AzureRmDiskAccess -ResourceGroupName $StepTemplate_ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name -DurationInSecond 3600 -Access Read 
        $vhdSasUri = $manageDisk.AccessSAS
    }
    if ($isUnmanagedVm) {
        Write-Host "Saving Unmanaged Image of $($vm.Name)..."
        $armTemplatePath = [System.IO.Path]::GetTempFileName()
        $vhdDestContainer = Get-OctopusSetting VhdDestContainer 'images'
        Save-AzureRmVMImage -ResourceGroupName $StepTemplate_ResourceGroupName -Name $StepTemplate_VMName -DestinationContainerName $vhdDestContainer -VHDNamePrefix $StepTemplate_ImageName -Overwrite -Path $armTemplatePath | Out-Verbose
        $armTemplate = Get-Content -Path $armTemplatePath
        "VM Image ARM Template:`n$armTemplate" | Out-Verbose
        Remove-Item $armTemplatePath -Force
        $osDiskUri = ($armTemplate | ConvertFrom-Json).resources.properties.storageprofile.osdisk.image.uri
        "OS Disk Image URI: $osDiskUri" | Out-Verbose
        $unmanagedVhd = Split-BlobUri $osDiskUri
        
        Write-Host "Granting access to vhd image ($($unmanagedVhd.Blob))..."
        $unmanagedVhdStorageResource = Find-AzureRmResource -ResourceNameEquals $unmanagedVhd.Account -ResourceType Microsoft.Storage/storageAccounts
        $unmanagedVhdStorageResource | Out-Verbose
        $unmanagedVhdStorageContext = Get-AzureRmStorageAccount -ResourceGroupName $unmanagedVhdStorageResource.ResourceGroupName -Name $unmanagedVhdStorageResource.Name | % Context
        $vhdSasUri = New-AzureStorageBlobSASToken -Container $unmanagedVhd.Container -Blob $unmanagedVhd.Blob -Permission r -ExpiryTime (Get-Date).AddHours(1) -FullUri -Context $unmanagedVhdStorageContext
    }
    Write-Host "Source image SAS token created: $vhdSasUri"

    Write-Host 'Copying image to storage account...'
    $destContainerName = Get-OctopusSetting VhdDestContainer 'images'
    $destContainer = Get-AzureStorageContainer -Name $destContainerName -Context $StepTemplate_ImageStorageContext -ErrorAction SilentlyContinue
    if ($destContainer) {
        Write-Host "Using container '$destContainerName' in storage account $StepTemplate_ImageDest..."
    } else {
        Write-Host "Creating container '$destContainerName' in storage account $StepTemplate_ImageDest..."
        $destContainer = New-AzureStorageContainer -Name $destContainerName -Context $StepTemplate_ImageStorageContext -Permission Off
    }

    $copyBlob = Start-AzureStorageBlobCopy -AbsoluteUri $vhdSasUri -DestContainer $destContainerName -DestContext $StepTemplate_ImageStorageContext -DestBlob $StepTemplate_ImageName -Force
    $copyBlob | Out-Verbose
    do {   
        if ($copyState.Status -eq 'Pending') {
            Start-Sleep -Seconds 60
        }
        $copyState = $copyBlob | Get-AzureStorageBlobCopyState
        $copyState | Out-Verbose
        $percent = ($copyState.BytesCopied / $copyState.TotalBytes) * 100
        Write-Host "Blob transfer $($copyState.Status.ToString().ToLower())... $('{0:N2}' -f $percent)% @ $([System.Math]::Round($copyState.BytesCopied/1GB, 2))GB / $([System.Math]::Round($copyState.TotalBytes/1GB, 2))GB"
    } while ($copyState.Status -eq 'Pending')
    Write-Host "Final image transfer status: $($copyState.Status)"
    
    if ($isManagedVm) {
        Write-Host 'Revoking access to os disk blob...'
        Revoke-AzureRmDiskAccess -ResourceGroupName $StepTemplate_ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name | Out-Verbose
    }
}

Write-Host "Image of $($vm.Name) captured successfully!"

if ($StepTemplate_DeleteVMResourceGroup -ieq 'True') {
    Write-Host ('-'*80)
    Write-Host "Removing $($vm.Name) VM's resource group $StepTemplate_ResourceGroupName, the following resources will be deleted..."
    Find-AzureRmResource -ResourceGroupNameEquals $StepTemplate_ResourceGroupName | Sort-Object -Property ResourceId -Descending | Select-Object -Property ResourceGroupName,ResourceType,ResourceName | Format-Table -AutoSize | Out-Host
    Remove-AzureRmResourceGroup -Name $StepTemplate_ResourceGroupName -Force | Out-Verbose
}