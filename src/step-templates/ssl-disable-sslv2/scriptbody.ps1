Write-host "Server : $Server"
	$ClientEnabled = $false
	$ServerEnabled = $false
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Server)
    $regkey = $reg.OpenSubkey("SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\SSL 2.0",$true)
	$regkeyC = $reg.OpenSubkey("SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\SSL 2.0\\Client",$true)
	$regkeyS = $reg.OpenSubkey("SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\SSL 2.0\\Server",$true)
	
	foreach($subkeyName in $regkey.GetSubKeyNames())
	{
#CLIENT
		# Check for Client SubKey
		if (!$regkeyC)			
		{
			$regkey.CreateSubKey('Client')
			#reload
			$regkeyC = $reg.OpenSubkey("SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\SSL 2.0\\Client",$true)
			$regkeyC.SetValue('DisabledByDefault','1','DWORD')
		}		
		foreach($subkeyNameC in $regkeyC.GetValueNames())
		{					
			if ($subkeyNameC)
			{
				if ($subkeyNameC -eq 'Enabled')
				{
					$ClientEnabled = $true
				}
			}
		}
		# Check to see if the Enabled Key was found
		if (!$ClientEnabled)
		{
			#Add enabled SubKey with DWORD value
			$regkeyC.SetValue('Enabled','0','DWORD')				
		}
#SERVER
		# Check for Server SubKey
		if (!$regkeyS)
		{
			$regkey.CreateSubKey('Server')
			#reload
			$regkeyS = $reg.OpenSubkey("SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\SSL 2.0\\Server",$true)
		}		
		foreach($subkeyNameS in $regkeyS.GetValueNames())
		{
			if ($subkeyNameS)
			{
				if ($subkeyNameS -eq 'Enabled')
				{
					$ServerEnabled = $true
				}
			}
		}		
		if (!$ServerEnabled)
		{
			#Add enabled SubKey with DWORD value
			$regkeyS.SetValue('Enabled','0','DWORD')
		}			
	} 
	Write-host "Server : $Server : Complete"