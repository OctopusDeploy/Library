$DeployedPath = $OctopusParameters["Octopus.Action[$NugetPackageStepName].Output.Package.InstallationDirectoryPath"]
$ReleaseNumber = $OctopusParameters["Octopus.Release.Number"]

Write-Host "Deploy Path: $DeployedPath"
Write-Host "Release Number: $ReleaseNumber"

function Deploy-SPSolution($wsp) {

	$wspName = $wsp.SubString($wsp.LastIndexOf("\") + 1)

	$solution = Get-SPSolution -Identity $wspName -ErrorAction silentlycontinue

	if ($solution -ne $null) 
	{ 
	    Write-Output "'$wspName' solution already installed - removing solution"
		
		# need to take a back up of this wsp before uninstalling it.		
		if($solution.ContainsWebApplicationResource) {
	        $solution | Uninstall-SPSolution -AllWebApplications -Confirm:$false
	    }
	    else {
	        $solution | Uninstall-SPSolution -Confirm:$false
	    }
		
		while ($solution.JobExists) {
		    Start-Sleep 30
		}
		
		Write-Output "$wspName has been uninstalled successfully."

	    Write-Output "Removing '$wspName' solution from farm" 
	    $solution | Remove-SPSolution -Force -Confirm:$false 
	
		# now install 
		Write-Output "Installing solution '$wspName'" 
		Add-SPSolution -LiteralPath "$wsp" | Out-Null
		
		Write-Output "$wsp solution added sucessfully"
		if(($solution -ne $null) -and ($solution.ContainsWebApplicationResource)) {
			Install-SPSolution -Identity $wspName –AllwebApplications -GACDeployment -Force -Confirm:$false
		}
		else {
			Install-SPSolution -Identity $wspName -GACDeployment -Force -Confirm:$false
		}

		<#
		while ($Solution.Deployed -eq $false) {
		    Start-Sleep 30
		}
		#>
	}
	else {
		Write-Output "Installing solution '$wspName'" 
		Add-SPSolution -LiteralPath "$wsp"  -ErrorAction Stop
		Install-SPSolution -Identity $wspName -GACDeployment -Force -ErrorAction Stop
	}
}

function Start-AdminService() {
	$AdminServiceName = "SPAdminV4"
	
	if ($(Get-Service $AdminServiceName).Status -eq "Stopped") {
	    Start-Service $AdminServiceName
	   	Write-Host "$AdminServiceName service was not running, now started."
		return $false;
	}
	
	return $true
}

function Stop-AdminService($IsAdminServiceWasRunning) {
	$AdminServiceName = "SPAdminV4"	
	if ($IsAdminServiceWasRunning -eq $false ) { 
		Stop-Service $AdminServiceName	
	}
}

#region Main
try
{
	# add powershell snap in for sharepoint functions
	if ((Get-PSSnapin "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue) -eq $null) { 
	    Add-PSSnapin "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue
	}
	
	#Admin service
	$IsAdminServiceWasRunning = $true;
	
	$IsAdminServiceWasRunning = Start-AdminService
	
	$wspFiles = @()
	
	# get all report files for deployment
    Write-Host "Getting all .wsp files"
    Get-ChildItem $DeployedPath -Recurse -Filter "*.wsp" | ForEach-Object { If(($wspFiles -contains $_.FullName) -eq $false) {$wspFiles += $_.FullName}}
    Write-Host "# of wsp files found: $($wspFiles.Count)"
	
	# loop through array
    foreach($wsp in $wspFiles) {
		Deploy-SPSolution $wsp
	}	
	
	Stop-AdminService $IsAdminServiceWasRunning
	
	#Remove SharePoint Snapin
	Remove-PsSnapin Microsoft.SharePoint.PowerShell
}
finally
{
    
}

#endregion