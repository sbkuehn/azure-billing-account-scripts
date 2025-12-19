$r = Invoke-AzRestMethod -Method GET `
  -Path "/providers/Microsoft.Billing/billingAccounts/$billingAccountName/billingSubscriptions?api-version=2024-04-01"

$d = ($r.Content -is [string]) ? ($r.Content | ConvertFrom-Json) : $r.Content
$subs = $d.value

$subs |
Select-Object `
  @{n="Name";e={$_.properties.displayName}},
  @{n="SubscriptionId";e={$_.properties.subscriptionId}},
  @{n="OfferId";e={$_.properties.offerId}},
  @{n="Status";e={$_.properties.status}} |
Format-Table -AutoSize
