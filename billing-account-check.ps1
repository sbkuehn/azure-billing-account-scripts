Connect-AzAccount

$accounts = Invoke-AzRestMethod -Method GET `
  -Path "/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01"

($accounts.Content | ConvertFrom-Json).value |
Select-Object name,
              @{n="DisplayName";e={$_.properties.displayName}} |
Format-Table -AutoSize
