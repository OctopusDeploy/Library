Add-PSSnapIn iControlSnapIn. F5 iControlSnapIn can be downloaded from here https://devcentral.f5.com/articles/icontrol-cmdlets 

Initialize-F5.iControl -HostName $OctopusParameters['HostName'] -Username $OctopusParameters['Username'] -Password $OctopusParameters['Password']

$Pool = $OctopusParameters['PoolName'];

$PoolA = (, $Pool);
$MemberEnabledState = New-Object -TypeName iControl.GlobalLBPoolMemberMemberEnabledState;
$MemberEnabledState.member = New-Object iControl.CommonIPPortDefinition;
$MemberEnabledState.member.address = $OctopusParameters['MemberIP'];
$MemberEnabledState.member.port = $OctopusParameters['MemberPort'];
$MemberEnabledState.state = $OctopusParameters['EnableOrDisable'];
[iControl.GlobalLBPoolMemberMemberEnabledState[]]$MemberEnabledStateA = [iControl.GlobalLBPoolMemberMemberEnabledState[]](, $MemberEnabledState);
[iControl.GlobalLBPoolMemberMemberEnabledState[][]]$MemberEnabledStateAofA = [iControl.GlobalLBPoolMemberMemberEnabledState[][]](, $MemberEnabledStateA);

(Get-F5.iControl).GlobalLBPoolMember.set_enabled_state($PoolA, $MemberEnabledStateAofA);