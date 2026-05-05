function Execute-RegexFindReplace($target, $find, $replace, $options) {
    Write-Output "Searching $target..."
    $orig = [System.IO.File]::ReadAllText($target)
    
    $regex = new-object System.Text.RegularExpressions.Regex($find, $options)
    if ([string]::IsNullOrEmpty($replace)) {        
$replace = ''
    }
    
    $occurrences = $regex.Matches($orig).Count
    if ($occurrences -gt 0) {
        Write-Output "Found $occurrences occurrence(s), replacing..."
        
        $replaced = $regex.Replace($orig, $replace)
        [System.IO.File]::WriteAllText($target, $replaced)
    }
}

if ([string]::IsNullOrEmpty($RFRFindRegex)) {
    throw "A non-empty 'Pattern' is required"
}

$options = [System.Text.RegularExpressions.RegexOptions]::None
$RFROptions.Split(' ') | foreach {
    $opt = $_.Trim()
    $flag = [System.Enum]::Parse([System.Text.RegularExpressions.RegexOptions], $opt)
    $options = $options -bor $flag
}

Write-Output "Replacing occurrences of '$RFRFindRegex' with '$RFRSubstitution' applying options $RFROptions"

$RFRCandidatePathGlobs.Split(";") | foreach {
    $glob = $_.Trim()
    Write-Output "Searching for files that match $glob..."

    $matches = $null
    $splits = $glob.Split(@('/**/'), [System.StringSplitOptions]::RemoveEmptyEntries)

    if ($splits.Length -eq 1) {
        $splits = $glob.Split(@('\**\'), [System.StringSplitOptions]::RemoveEmptyEntries)
    }
    
    if ($splits.Length -eq 1) {
        $matches = ls $glob
    } else {
        if ($splits.Length -eq 2) {
            pushd $splits[0]
            $matches = ls $splits[1] -Recurse
            popd
        } else {
            $splits
            throw "The segment '**' can only appear once, as a directory name, in the glob expression"

        }
    }

    $matches | foreach {
        
        $target = $_.FullName

        Execute-RegexFindReplace -target $target -find $RFRFindRegex -replace $RFRSubstitution -options $options
    }
}


Write-Output "Done."