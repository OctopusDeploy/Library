If ([System.Net.ServicePointManager]::CertificatePolicy -ne $null)
{
add-type @" 
    using System.Net; 
    using System.Security.Cryptography.X509Certificates; 

    public class NoSSLCheckPolicy : ICertificatePolicy { 
        public NoSSLCheckPolicy() {} 
        public bool CheckValidationResult( 
            ServicePoint sPoint, X509Certificate cert, 
            WebRequest wRequest, int certProb) { 
            return true; 
        } 
    } 
"@ 
[System.Net.ServicePointManager]::CertificatePolicy = new-object NoSSLCheckPolicy 
}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] "Ssl3"


# Check the parameters.
if (-NOT $SplunkHost) { throw "You must enter a value for 'Splunk Host'." }
if (-NOT $SplunkEventCollectorPort) { throw "You must enter a value for 'Splunk Event Collector Port'." }
if (-NOT $SplunkEventCollectorToken) { throw "You must enter a value for 'Event Collector Token'." } 
if (-NOT $Message) { throw "You must enter a value for 'Message'." } 
  
$properties = @{
Message = $Message;
ProjectName = $OctopusParameters['Octopus.Project.Name'];
ReleaseNumber = $OctopusParameters['Octopus.Release.Number']; 
EnvironmentName = $OctopusParameters['Octopus.Environment.Name'];
DeploymentName = $OctopusParameters['Octopus.Deployment.Name'];
Channel = $OctopusParameters['Octopus.Release.Channel.Name']; 
ReleaseUri = $OctopusParameters['Octopus.Web.ReleaseLink'];
DeploymentUri = $OctopusParameters['Octopus.Web.DeploymentLink'];
DeploymentCreatedBy = $OctopusParameters['Octopus.Deployment.CreatedBy.Username'];
Comments = $OctopusParameters['Octopus.Deployment.Comments'];
}  

$exception = $null
if ($OctopusParameters['Octopus.Deployment.Error']) {  
    $properties["DeploymentError"] = $OctopusParameters['Octopus.Deployment.Error']
    $properties["DeploymentDetailedError"] = $OctopusParameters['Octopus.Deployment.ErrorDetail']
}  

$body = @{
    event =(ConvertTo-Json $properties)
}
 
$uri = "https://" + $SplunkHost + ":" + $SplunkEventCollectorPort + "/services/collector"
$header = @{"Authorization"="Splunk " + $SplunkEventCollectorToken}

Invoke-RestMethod -Method Post -Uri $uri -Body (ConvertTo-Json $body) -Header $header
