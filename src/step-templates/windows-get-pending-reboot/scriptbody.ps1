$TempErrAct = $ErrorActionPreference 
    $ErrorActionPreference = "Stop"   
    Foreach ($Computer in $ComputerName) 
      { 
        Try 
          { 
            # Setting pending values to false to cut down on the number of else statements 
            $PendFileRename,$Pending,$SCCM = $false,$false,$false 
			
            # Setting CBSRebootPend to null since not all versions of Windows has this value 
            $CBSRebootPend = $null 
			
            # Querying WMI for build version 
            $WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -Property BuildNumber, CSName -ComputerName $Computer 
			
            # Making registry connection to the local/remote computer 
            $RegCon = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"LocalMachine",$Computer) 
			
            # If Vista/2008 & Above query the CBS Reg Key 
            If ($WMI_OS.BuildNumber -ge 6001) 
              { 
                $RegSubKeysCBS = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\").GetSubKeyNames() 
                $CBSRebootPend = $RegSubKeysCBS -contains "RebootPending" 
              }#End If ($WMI_OS.BuildNumber -ge 6001) 
			  
            # Query WUAU from the registry 
            $RegWUAU = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\") 
            $RegWUAURebootReq = $RegWUAU.GetSubKeyNames() 
            $WUAURebootReq = $RegWUAURebootReq -contains "RebootRequired" 
			
            # Query PendingFileRenameOperations from the registry 
            $RegSubKeySM = $RegCon.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\") 
            $RegValuePFRO = $RegSubKeySM.GetValue("PendingFileRenameOperations",$null) 
			
            # Closing registry connection 
            $RegCon.Close() 
			
            # If PendingFileRenameOperations has a value set $RegValuePFRO variable to $true 
            If ($RegValuePFRO) 
              { 
                $PendFileRename = $true 
              }#End If ($RegValuePFRO) 
           
            # If any of the variables are true, set $Pending variable to $true 
            If ($CBSRebootPend -or $WUAURebootReq -or $PendFileRename) 
              { 
                $Pending = $true 
              }#End If ($CBS -or $WUAU -or $PendFileRename) 
            # Creating Custom PSObject and Select-Object Splat 
			$SelectSplat = @{ 
			    Property=('Computer','CBServicing','WindowsUpdate','PendFileRename','PendFileRenVal','RebootPending') 
			    } 
            New-Object -TypeName PSObject -Property @{ 
                Computer=$WMI_OS.CSName 
                CBServicing=$CBSRebootPend 
                WindowsUpdate=$WUAURebootReq 
                PendFileRename=$PendFileRename 
                PendFileRenVal=$RegValuePFRO 
                RebootPending=$Pending 
                } | Select-Object @SelectSplat 
          }#End Try 
        Catch 
          { 
            Write-Warning "$Computer`: $_" 
            # If $ErrorLog, log the file to a user specified location/path 
            If ($ErrorLog) 
              { 
                Out-File -InputObject "$Computer`,$_" -FilePath $ErrorLog -Append 
              }#End If ($ErrorLog) 
          }#End Catch 
      }#End Foreach ($Computer in $ComputerName) 
	  $ErrorActionPreference = $TempErrAct 