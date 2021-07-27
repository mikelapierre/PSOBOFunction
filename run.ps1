using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Get the subscription from the query or body
$subscription = $Request.Query.Subscription
if (-not $subscription) {
    $name = $Request.Body.Subscription
}

# Request an OBO token for ARM
$tenantId = $env:WEBSITE_AUTH_OPENID_ISSUER.Split("/")[3]
$reqestBody = @{
    client_id           = $env:WEBSITE_AUTH_CLIENT_ID
    client_secret       = [Environment]::GetEnvironmentVariable($env:WEBSITE_AUTH_CLIENT_SECRET_SETTING_NAME)
    grant_type          = "urn:ietf:params:oauth:grant-type:jwt-bearer"
    scope               = "https://management.azure.com/user_impersonation"    
    requested_token_use = "on_behalf_of"
    assertion           = $Request.Headers["authorization"].Substring(7)
}
$auth = Invoke-RestMethod -Method post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $reqestBody

# Connect using the OBO token
Disable-AzContextAutosave -Scope Process | Out-Null
Connect-AzAccount -AccountId $Request.Headers["x-ms-client-principal-id"] -AccessToken $auth.access_token
Set-AzContext -Subscription $subscription
Get-AzWebApp | % { $body = $body + $_.Name  + "`r`n" }

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
