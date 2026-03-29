# Running outside octopus
param(
    [string]$MsiFilePath,
	[ValidateSet("Install", "Repair", "Remove", IgnoreCase=$true)]
	[string]$Action,
	[string]$ActionModifier,
    [string]$LoggingOptions = "*",
    [ValidateSet("False", "True")]
    [string]$LogAsArtifact,
	[string]$Properties,
	[int[]]$IgnoredErrorCodes,
    [switch]$WhatIf
) 

$ErrorActionPreference = "Stop"

$ErrorMessages = @{
	"0" = "Action completed successfully.";
	"13" = "The data is invalid.";
	"87" = "One of the parameters was invalid.";
	"1601" = "The Windows Installer service could not be accessed. Contact your support personnel to verify that the Windows Installer service is properly registered.";
	"1602" = "User cancel installation.";
	"1603" = "Fatal error during installation.";
	"1604" = "Installation suspended, incomplete.";
	"1605" = "This action is only valid for products that are currently installed.";
	"1606" = "Feature ID not registered.";
	"1607" = "Component ID not registered.";
	"1608" = "Unknown property.";
	"1609" = "Handle is in an invalid state.";
	"1610" = "The configuration data for this product is corrupt. Contact your support personnel.";
	"1611" = "Component qualifier not present.";
	"1612" = "The installation source for this product is not available. Verify that the source exists and that you can access it.";
	"1613" = "This installation package cannot be installed by the Windows Installer service. You must install a Windows service pack that contains a newer version of the Windows Installer service.";
	"1614" = "Product is uninstalled.";
	"1615" = "SQL query syntax invalid or unsupported.";
	"1616" = "Record field does not exist.";
	"1618" = "Another installation is already in progress. Complete that installation before proceeding with this install.";
	"1619" = "This installation package could not be opened. Verify that the package exists and that you can access it, or contact the application vendor to verify that this is a valid Windows Installer package.";
	"1620" = "This installation package could not be opened. Contact the application vendor to verify that this is a valid Windows Installer package.";
	"1621" = "There was an error starting the Windows Installer service user interface. Contact your support personnel.";
	"1622" = "Error opening installation log file. Verify that the specified log file location exists and is writable.";
	"1623" = "This language of this installation package is not supported by your system.";
	"1624" = "Error applying transforms. Verify that the specified transform paths are valid.";
	"1625" = "This installation is forbidden by system policy. Contact your system administrator.";
	"1626" = "Function could not be executed.";
	"1627" = "Function failed during execution.";
	"1628" = "Invalid or unknown table specified.";
	"1629" = "Data supplied is of wrong type.";
	"1630" = "Data of this type is not supported.";
	"1631" = "The Windows Installer service failed to start. Contact your support personnel.";
	"1632" = "The temp folder is either full or inaccessible. Verify that the temp folder exists and that you can write to it.";
	"1633" = "This installation package is not supported on this platform. Contact your application vendor.";
	"1634" = "Component not used on this machine.";
	"1635" = "This patch package could not be opened. Verify that the patch package exists and that you can access it, or contact the application vendor to verify that this is a valid Windows Installer patch package.";
	"1636" = "This patch package could not be opened. Contact the application vendor to verify that this is a valid Windows Installer patch package.";
	"1637" = "This patch package cannot be processed by the Windows Installer service. You must install a Windows service pack that contains a newer version of the Windows Installer service.";
	"1638" = "Another version of this product is already installed. Installation of this version cannot continue. To configure or remove the existing version of this product, use Add/Remove Programs on the Control Panel.";
	"1639" = "Invalid command line argument. Consult the Windows Installer SDK for detailed command line help.";
	"1640" = "Installation from a Terminal Server client session not permitted for current user.";
	"1641" = "The installer has started a reboot.";
	"1642" = "The installer cannot install the upgrade patch because the program being upgraded may be missing, or the upgrade patch updates a different version of the program. Verify that the program to be upgraded exists on your computer and that you have the correct upgrade patch.";
	"3010" = "A restart is required to complete the install. This does not include installs where the ForceReboot action is run. Note that this error will not be available until future version of the installer."
};

function Get-Param($Name, [switch]$Required, $Default) {
    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue   
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    if ($result -eq $null) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

function Resolve-PotentialPath($Path) {
	[Environment]::CurrentDirectory = $pwd
	return [IO.Path]::GetFullPath($Path)
}

function Get-LogOptionFile($msiFile, $streamLog) {
	$logPath = Resolve-PotentialPath "$msiFile.log"
	
	if (Test-Path $logPath) {
		Remove-Item $logPath
	}
	
	return $logPath
}

function Exec
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
        [string]$errorMessage = ($msgs.error_bad_command -f $cmd),
		[switch]$ReturnCode
    )

	$lastexitcode = 0
    & $cmd
	
	if ($ReturnCode) {
		return $lastexitcode
	} else  {
		if ($lastexitcode -ne 0) {
			throw ("Exec: " + $errorMessage)
		}		
	}
}

function Wrap-Arguments($Arguments)
{
	return $Arguments | % { 
		
		[string]$val = $_
		
		#calling msiexec fails when arguments are quoted
		if (($val.StartsWith("/") -and $val.IndexOf(" ") -eq -1) -or ($val.IndexOf("=") -ne -1) -or ($val.IndexOf('"') -ne -1)) {
			return $val
		}
	
		return '"{0}"' -f $val
	}
}

function Start-Process2($FilePath, $ArgumentList, [switch]$showCall, [switch]$whatIf)
{
	$ArgumentListString = (Wrap-Arguments $ArgumentList) -Join " "

	$pinfo = New-Object System.Diagnostics.ProcessStartInfo
	$pinfo.FileName = $FilePath
	$pinfo.UseShellExecute = $false
	$pinfo.CreateNoWindow = $true
	$pinfo.RedirectStandardOutput = $true
	$pinfo.RedirectStandardError = $true
	$pinfo.Arguments = $ArgumentListString;
	$pinfo.WorkingDirectory = $pwd

	$exitCode = 0
	
	if (!$whatIf) {
	
		if ($showCall) {
			$x = Write-Output "$FilePath $ArgumentListString"
		}
		
		$p = New-Object System.Diagnostics.Process
		$p.StartInfo = $pinfo
		$started = $p.Start()
		$p.WaitForExit()

		$stdout = $p.StandardOutput.ReadToEnd()
		$stderr = $p.StandardError.ReadToEnd()
		$x = Write-Output $stdout
		$x = Write-Output $stderr
		
		$exitCode = $p.ExitCode
	} else {
		Write-Output "skipping: $FilePath $ArgumentListString"
	}
	
	return $exitCode
}

function Get-EscapedFilePath($FilePath)
{
    return [Management.Automation.WildcardPattern]::Escape($FilePath)
}

& {
    param(
        [string]$MsiFilePath,
		[string]$Action,
		[string]$ActionModifier,
        [string]$LoggingOptions,
        [bool]$LogAsArtifact,
		[string]$Properties,
		[int[]]$IgnoredErrorCodes
    ) 

    $MsiFilePathLeaf = Split-Path -Path $MsiFilePath -Leaf
    $EscapedMsiFilePath = Get-EscapedFilePath (Split-Path -Path $MsiFilePath)
    
	$MsiFilePath = Get-EscapedFilePath (Resolve-Path "$EscapedMsiFilePath\$MsiFilePathLeaf" | Select-Object -First 1).ProviderPath

    Write-Output "Installing MSI"
    Write-Host " MsiFilePath: $MsiFilePath" -f Gray
	Write-Host " Action: $Action" -f Gray
	Write-Host " Properties: $Properties" -f Gray
	Write-Host

	if ((Get-Command msiexec) -Eq $Null) {
		throw "Command msiexec could not be found"
	}
	
	if (!(Test-Path $MsiFilePath)) {
		throw "Could not find the file $MsiFilePath"
	}

	$actions = @{
		"Install" = "/i";
		"Repair" = "/f";
		"Remove" = "/x";
	};
	
	$actionOption = $actions[$action]
	$actionOptionFile = $MsiFilePath
	if ($ActionModifier)
	{
		$actionOption += $ActionModifier
	}
	
    if ($LoggingOptions) {
	    $logOption = "/L$LoggingOptions"
	    $logOptionFile = Get-LogOptionFile $MsiFilePath
	}
	$quiteOption = "/qn"
	$noRestartOption = "/norestart"
	
	$parameterOptions = $Properties -Split "\r\n?|\n" | ? { !([string]::IsNullOrEmpty($_)) } | % { $_.Trim() }
	
	$options = @($actionOption, $actionOptionFile, $logOption, $logOptionFile, $quiteOption, $noRestartOption) + $parameterOptions

	$exePath = "msiexec.exe"

	$exitCode = Start-Process2 -FilePath $exePath -ArgumentList $options -whatIf:$whatIf -ShowCall
	
	Write-Output "Exit Code was! $exitCode"
	
	if (Test-Path $logOptionFile) {

		Write-Output "Reading installer log"

        # always write out these (http://robmensching.com/blog/posts/2010/8/2/the-first-thing-i-do-with-an-msi-log/)
        (Get-Content $logOptionFile) | Select-String -SimpleMatch "value 3" -Context 10,0 | ForEach-Object { Write-Warning $_ }

        if ($LogAsArtifact) {
            New-OctopusArtifact -Path $logOptionFile -Name "$Action-$([IO.Path]::GetFileNameWithoutExtension($MsiFilePath)).log"
        } else {
	    	Get-Content $logOptionFile | Write-Output
        }

	} else {
		Write-Output "No logs were generated"
	}

	if ($exitCode -Ne 0) {
		$errorCodeString = $exitCode.ToString()
		$errorMessage = $ErrorMessages[$errorCodeString]
		
		if ($IgnoredErrorCodes -notcontains $exitCode) {

			throw "Error code $exitCodeString was returned: $errorMessage"
		}
		else {
			Write-Output "Error code [$exitCodeString] was ignored because it was in the IgnoredErrorCodes [$($IgnoredErrorCodes -join ',')] parameter. Error Message [$errorMessage]"
		}
	}
	
} `
(Get-Param 'MsiFilePath' -Required) `
(Get-Param 'Action' -Required) `
(Get-Param 'ActionModifier') `
(Get-Param 'LoggingOptions') `
((Get-Param 'LogAsArtifact') -eq "True") `
(Get-Param 'Properties') `
(Get-Param 'IgnoredErrorCodes')
