$headers = @{ Authorization = "#{launchdarkly-access-token}"; "content-type" = "application/json" }
$body = @( @{ op = "replace"; path = "/environments/#{launchdarkly-environment-key}/on"; value = #{if launchdarkly-flag-value}$true#{/if}#{unless launchdarkly-flag-value}$false#{/unless} } )
$bodyAsJson = ConvertTo-Json -InputObject $body -Compress

Invoke-RestMethod 'https://app.launchdarkly.com/api/v2/flags/#{launchdarkly-project-key}/#{launchdarkly-flag-key}' -Method Patch -Body $bodyAsJson -Headers $headers