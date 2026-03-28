# Running outside octopus
param(
    [string]$DllFilePaths,
    [string]$Uninstall
)

$ErrorActionPreference = "Stop" 

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

& {
    param(
        [string]$DllFilePaths,
        [string]$Uninstall
    ) 

    $isUninstall = $($Uninstall.ToLower() -eq 'true')

    Write-Host "COM Component - Register"
    Write-Host "DllFilePaths: $DllFilePaths"

    $DllFilePaths.split(";") | ForEach {
        $dllFilePath = $_.Trim();
        Write-Host $dllFilePath
        
        if($dllFilePath.Length -lt 1){
            break;
        }
        
        Write-Host "Attempting to register $dllFilePath"

        if(!(Test-Path "$dllFilePath"))
        {
            Write-Host "FILE NOT FOUND $dllFilePath." -ForegroundColor Yellow;
            return;
        }

         Write-Host "Attempting to register $dllFilePath"
    
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo

        $cmd = "$env:windir\System32\regsvr32.exe"

        Write-Host "Registering with: $env:windir\System32\regsvr32.exe"

        $pinfo.FileName = "$cmd"

        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        
        if($isUninstall){
            $args = "/u"
        }
        $args = "$args /s `"$dllFilePath`""

        $pinfo.Arguments = $args
        
        $p = New-Object System.Diagnostics.Process

        $p.StartInfo = $pinfo

        Write-Host "Command:"
        Write-Host "$cmd $args"

        if ($p.Start())
        {
            Write-Host $p.StandardOutput.ReadToEnd().ToString()

            if($p.ExitCode -ne 0)
            {
                
                Write-Host "FAILED $($p.ExitCode) - Register" -ForegroundColor Red 
                Write-Host $p.StandardError.ReadToEnd() -ForegroundColor Red
                                
                throw $p.StandardError.ReadToEnd()
            }
            
            Write-Host "SUCCESS- Register" -ForegroundColor Green 
        }

       
    }

 } `
 (Get-Param 'DllFilePaths' -Required) `
 (Get-Param 'Uninstall' -Required)