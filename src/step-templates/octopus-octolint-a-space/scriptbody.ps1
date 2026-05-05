$server = $OctopusParameters["Octolint.Octopus.ServerUri"]
$apiKey = $OctopusParameters["Octolint.Octopus.ApiKey"]
$spaceName = $OctopusParameters["Octolint.Octopus.SpaceName"]

docker pull octopussamples/octolint
docker run --rm octopussamples/octolint -url "$server" -apiKey "$apiKey" -space "$spaceName" -verboseErrors