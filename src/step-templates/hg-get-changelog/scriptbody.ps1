If ($OctopusParameters["Octopus.Release.CurrentForEnvironment.Number"]) {
    $prm = @('log',
    	'-r',"ancestors('release-$($OctopusParameters["Octopus.Release.Number"])') - ancestors('release-$($OctopusParameters["Octopus.Release.CurrentForEnvironment.Number"])')",
    	'-T',$Template,
    	'--repository',$HgRepository)
    Write-Host Getting changelog on $prm[6] '[' $prm[2] ']'
    $changelog = & hg $prm
}
Else {
    $changelog = "<li><i>(no changelog available)</i></li>"
}
Write-Verbose $changelog
Set-OctopusVariable -name "Changelog" -value $changelog