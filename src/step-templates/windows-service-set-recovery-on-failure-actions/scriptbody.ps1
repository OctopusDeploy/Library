cls
#ignore above

function main
{
    $serviceName = Get-OctoParameter -parameterName "ServiceName" -parameterDescription "Service Name"
    $firstFailureAction = Get-OctoParameter -parameterName "FirstFailureAction" -parameterDescription "First Failure Action" -default "restart"
    $secondFailureAction = Get-OctoParameter -parameterName "SecondFailureAction" -parameterDescription "Second Failure Action" -default "restart"
    $thirdFailureAction = Get-OctoParameter -parameterName "ThirdFailureAction" -parameterDescription "Third Failure Action" -default "restart"
    $firstFailureDelay = Get-OctoParameter -parameterName "FirstFailureDelay" -parameterDescription "First Failure Delay" -default 180000
    $secondFailureDelay = Get-OctoParameter -parameterName "SecondFailureDelay" -parameterDescription "Second Failure Delay" -default 180000
    $thirdFailureDelay = Get-OctoParameter -parameterName "ThirdFailureDelay" -parameterDescription "Third Failure Delay" -default 180000
    $reset = Get-OctoParameter -parameterName "Reset" -parameterDescription "Reset" -default 86400

    $service = Get-Service $serviceName -ErrorAction SilentlyContinue

    if (!$service)
    {
        Write-Host "Windows Service '$serviceName' not found, skipping."
        return
    }

    echo "Updating the '$serviceName' service with recovery options..."
    echo "    On first failure '$firstFailureAction' after '$firstFailureDelay' milliseconds."
    echo "    On second failure '$secondFailureAction' after '$secondFailureDelay' milliseconds."
    echo "    On third failure '$thirdFailureAction' after '$thirdFailureDelay' milliseconds."
    echo "    Reset after '$reset' minutes."

    sc.exe failure $service.Name actions= $firstFailureAction/$firstFailureDelay/$secondFailureAction/$secondFailureDelay/$thirdFailureAction/$thirdFailureDelay reset= $reset

    echo "Done"
}

function Get-OctoParameter() 
{
    Param
    (
        [Parameter(Mandatory=$true)]$parameterName,
        [Parameter(Mandatory=$true)]$parameterDescription,
        [Parameter(Mandatory=$false)]$default
    )

    $ErrorActionPreference = "SilentlyContinue" 
    $value = $OctopusParameters[$parameterName] 
    $ErrorActionPreference = "Stop" 
    
    if (! $value) 
    {
        if(! $default) 
        {
            throw "'$parameterDescription' cannot be empty, please specify a value."
        }

        return $default
    }
    
    return $value
}

main