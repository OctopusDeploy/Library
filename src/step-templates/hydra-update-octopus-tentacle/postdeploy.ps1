if ([System.String]::IsNullOrEmpty($ServerMapping)) {
    & .\Hydra.exe --defer
} else {
    $cleanServerMapping = $ServerMapping.Replace(" ","")
    & .\Hydra.exe --defer --servers=$cleanServerMapping
}
