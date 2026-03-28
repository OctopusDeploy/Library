function Execute-FindReplace($target, $find, $replace, $ignoreCase) {
    $options = [System.Text.RegularExpressions.RegexOptions]::None
    if ($ignoreCase) {
        $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    }
    
    Write-Output "Searching $target..."
    $orig = [System.IO.File]::ReadAllText($target)
    
    $escFind = [System.Text.RegularExpressions.Regex]::Escape($find)
    $regex = new-object System.Text.RegularExpressions.Regex($escFind, $options)
    $removed = $regex.Replace($orig, '')
    
    $occurrences = ($orig.Length - $removed.Length) / $find.Length
    if ($occurrences -gt 0) {
        Write-Output "Found $occurrences occurrence(s), replacing..."
        
        $escReplace = $replace.Replace('$', '$$')
        $replaced = $regex.Replace($orig, $escReplace)
        [System.IO.File]::WriteAllText($target, $replaced)
    }
}

if ([string]::IsNullOrEmpty($FRFindText)) {
    throw "A non-empty 'Find' text block is required"
}

Write-Output "Replacing occurrences of '$FRFindText' with '$FRReplaceText'"
if ([Boolean] $FRIgnoreCase) {
    Write-Output "Case will be ignored"
}

$FRCandidatePathGlobs.Split(";") | foreach {
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

        Execute-FindReplace -target $target -find $FRFindText -replace $FRReplaceText -ignoreCase ([Boolean] $FRIgnoreCase)
    }
}


Write-Output "Done."