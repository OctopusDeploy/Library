[xml]$xml = Get-Content $path 
$ns = new-object Xml.XmlNamespaceManager $xml.NameTable
$ns.AddNamespace($nsKey, $nsValue)

$xml.SelectNodes($xmlPath, $ns) | % {
	if ($_.key -eq $key)
	{
		$_.value = $value
	}
}

$xml.Save($path)