function Slack-Populate-StatusInfo ([boolean] $Success = $true) {

	$deployment_info = $OctopusParameters['DeploymentInfoText'];
	
	if ($Success){
		$status_info = @{
			color = "good";
			
			title = "Success";
			message = "$deployment_info";

			fallback = "Deployed successfully $deployment_info";
			
			success = $Success;
		}
	} else {
		$status_info = @{
			color = "danger";
			
			title = "Failed";			
			message = "$deployment_info";

			fallback = "Failed to deploy $deployment_info";	
			
			success = $Success;
		}
	}
	
	return $status_info;
}

function Slack-Populate-Fields ($StatusInfo) {

	# We use += instead of .Add() to prevent returning values returned by .Add() function
	# it clutters the code, but seems the easiest solution here
	
	$fields = @()
	
	$fields += 
		@{
			title = $StatusInfo.title;
			value = $StatusInfo.message;
		}
	;

	$IncludeFieldEnvironment = [boolean]::Parse($OctopusParameters['IncludeFieldEnvironment'])
	if ($IncludeFieldEnvironment) {
		$fields += 
			@{
				title = "Environment";
				value = $OctopusEnvironmentName;
				short = "true";
			}
		;	
	}


	$IncludeFieldMachine = [boolean]::Parse($OctopusParameters['IncludeFieldMachine'])
	if ($IncludeFieldMachine) {
		$fields += 
			@{
				title = "Machine";
				value = $OctopusParameters['Octopus.Machine.Name'];
				short = "true";
			}
		;	
	}	
	
	$IncludeFieldTenant = [boolean]::Parse($OctopusParameters['IncludeFieldTenant'])
	if ($IncludeFieldTenant) {
		$fields += 
			@{
				title = "Tenant";
				value = $OctopusParameters['Octopus.Deployment.Tenant.Name'];
				short = "true";
			}
		;	
	}	
	
	$IncludeFieldUsername = [boolean]::Parse($OctopusParameters['IncludeFieldUsername'])
	if ($IncludeFieldUsername) {
		$fields += 
			@{
				title = "Username";
				value = $OctopusParameters['Octopus.Deployment.CreatedBy.Username'];
				short = "true";
			}
		;	
	}	
	
	$IncludeFieldRelease = [boolean]::Parse($OctopusParameters['IncludeFieldRelease'])
	if ($IncludeFieldRelease) {
		$fields += 
			@{
				title = "Release";
				value = $OctopusReleaseNumber;
				short = "true";
			}
		;	
	}
	
	
	$IncludeFieldReleaseNotes = [boolean]::Parse($OctopusParameters['IncludeFieldReleaseNotes'])
	if ($StatusInfo["success"] -and $IncludeFieldReleaseNotes) {
    
		$link = $OctopusParameters['Octopus.Web.ReleaseLink'];
		$baseurl = $OctopusParameters['OctopusBaseUrl'];
		
		# Handle double quotes in the notes
        $notes = $OctopusParameters['Octopus.Release.Notes'].Replace("`"", "\""")
		
		if ($notes.Length -gt 300) {
			$shortened = $notes.Substring(0,300);
			$notes = "$shortened `n `<${baseurl}${link}|view all changes`>"
		}
		
		$fields +=  
			@{
				title = "Changes in this release";
				value = $notes;
			}
		;	
	}	
	
	#failure fields
	
	$IncludeErrorMessageOnFailure = [boolean]::Parse($OctopusParameters['IncludeErrorMessageOnFailure'])
	if (-not  $StatusInfo["success"] -and $IncludeErrorMessageOnFailure) {
			
		$fields += 
			@{
				title = "Error text";
				value = $OctopusParameters['Octopus.Deployment.Error'];
			}
		;	
	}	
		

	$IncludeLinkOnFailure = [boolean]::Parse($OctopusParameters['IncludeLinkOnFailure'])
	if (-not $StatusInfo["success"] -and $IncludeLinkOnFailure) {
		
		$link = $OctopusParameters['Octopus.Web.DeploymentLink'];
		$baseurl = $OctopusParameters['OctopusBaseUrl'];
	
		$fields += 
			@{
				title = "See the process";
				value = "`<${baseurl}${link}|Open process page`>";
				short = "true";
			}
		;	
	}
	
	
	return $fields;
	
}

function Slack-Rich-Notification ($Success)
{
    $status_info = Slack-Populate-StatusInfo -Success $Success
	$fields = Slack-Populate-Fields -StatusInfo $status_info

	
	$payload = @{
        channel = $OctopusParameters['Channel']
        username = $OctopusParameters['Username'];
        icon_url = $OctopusParameters['IconUrl'];
		
        attachments = @(
            @{
				fallback = $status_info["fallback"];
				color = $status_info["color"];
			
				fields = $fields
            };
        );
    }
	
	#We unescape here to allow links in the Json, as ConvertTo-Json escapes <,> and other special symbols
	$json_body = ($payload | ConvertTo-Json -Depth 4 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) });

	
    try {
    	$invokeParameters = @{}
        $invokeParameters.Add("Method", "POST")
        $invokeParameters.Add("Body", $json_body)
        $invokeParameters.Add("Uri", $OctopusParameters['HookUrl'])
        $invokeParameters.Add("ContentType", "application/json")
        
            # Check for UseBasicParsing
        if ((Get-Command Invoke-RestMethod).Parameters.ContainsKey("UseBasicParsing"))
        {
            # Add the basic parsing argument
            $invokeParameters.Add("UseBasicParsing", $true)
        }

        
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-RestMethod @invokeParameters
        
    } catch {
        echo "Something occured"
        echo  $_.Exception
        echo  $_
        #echo $json_body
        throw
    }
    
}



$success = ($OctopusParameters['Octopus.Deployment.Error'] -eq $null);

Slack-Rich-Notification -Success $success
