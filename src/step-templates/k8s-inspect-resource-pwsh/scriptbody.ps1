<#
    This script provides a general purpose method for querying Kubernetes resources. It supports common operations
    like get, describe, logs and output formats like yaml and json. Output can be captured as artifacts.
#>

<#
.Description
Execute an application, capturing the output. Based on https://stackoverflow.com/a/33652732/157605
#>
Function Execute-Command ($commandPath, $commandArguments)
{
  Write-Host "Executing: $commandPath $($commandArguments -join " ")"
  
  Try {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $commandPath
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $commandArguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    [pscustomobject]@{
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        ExitCode = $p.ExitCode
    }
    $p.WaitForExit()
  }
  Catch {
     exit
  }
}

<#
.Description
Find any resource names that match a wildcard input if one was specified
#>
function Get-Resources() 
{
    $names = $OctopusParameters["K8SInspectNames"] -Split "`n" | % {$_.Trim()}
    
    if ($OctopusParameters["K8SInspectNames"] -match '\*' )
    {
        return Execute-Command kubectl (@("-o", "json", "get", $OctopusParameters["K8SInspectResource"])) |
            # Select the stdout property from the execution
            Select-Object -ExpandProperty stdout |
            # Convert the output from JSON
            ConvertFrom-JSON | 
            # Get the items object from the kubectl response
            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |
            # Extract the name
            % {$_.metadata.name} |
            # Find any matching resources
            ? {$k8sName = $_; ($names | ? {$k8sName -like $_}).Count -ne 0}
    }
    else
    {
        return $names
    }
}

<#
.Description
Get the kubectl arguments for a given action
#>
function Get-KubectlVerb() 
{
    switch($OctopusParameters["K8SInspectKubectlVerb"])
    {
        "get json" {return ,@("-o", "json", "get")}
        "get yaml" {return ,@("-o", "yaml", "get")}
        "describe" {return ,@("describe")}
        "logs" {return ,@("logs")}
        "logs tail" {return ,@("logs", "--tail", "100")}
        "previous logs" {return ,@("logs", "--previous")}
        "previous logs tail" {return ,@("logs", "--previous", "--tail", "100")}
        default {return ,@("get")}
    }
}

<#
.Description
Get an appropiate file extension based on the selected action
#>
function Get-ArtifactExtension() 
{
   switch($OctopusParameters["K8SInspectKubectlVerb"])
    {
        "get json" {"json"}
        "get yaml" {"yaml"}
        default {"txt"}
    }
}

if ($OctopusParameters["K8SInspectKubectlVerb"] -like "*logs*") 
{
    if ( -not @($OctopusParameters["K8SInspectResource"]) -like "pod*")
    {
        Write-Error "Logs can only be returned for pods, not $($OctopusParameters["K8SInspectResource"])"
    }
    else
    {
        Execute-Command kubectl (@("-o", "json", "get", "pods") + (Get-Resources)) |
            # Select the stdout property from the execution
            Select-Object -ExpandProperty stdout |
            # Convert the output from JSON
            ConvertFrom-JSON | 
            # Get the items object from the kubectl response
            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |
            # Get the pod logs for each container
            % {
                $podDetails = $_
                @{
                    logs=$podDetails.spec.containers | % {$logs=""} {$logs += (Select-Object -InputObject (Execute-Command kubectl ((Get-KubectlVerb) + @($podDetails.metadata.name, "-c", $_.name))) -ExpandProperty stdout)} {$logs}; 
                    name=$podDetails.metadata.name
                }                
            } |
            # Write the output
            % {Write-Host $_.logs; $_} |
            # Optionally capture the artifact
            % {
                if ($OctopusParameters["K8SInspectCreateArtifact"] -ieq "true") 
                {
                    Set-Content -Path "$($_.name).$(Get-ArtifactExtension)" -Value $_.logs
                    New-OctopusArtifact "$($_.name).$(Get-ArtifactExtension)"
                }
            }
    }      
}
else
{
    Execute-Command kubectl ((Get-KubectlVerb) + @($OctopusParameters["K8SInspectResource"]) + (Get-Resources)) |
        % {Select-Object -InputObject $_ -ExpandProperty stdout} |
        % {Write-Host $_; $_} |
        % {
            if ($OctopusParameters["K8SInspectCreateArtifact"] -ieq "true") 
            {
                Set-Content -Path "output.$(Get-ArtifactExtension)" -Value $_
                New-OctopusArtifact "output.$(Get-ArtifactExtension)"
            }
        }
}
