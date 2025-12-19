Connect-AzAccount | Out-Null

$arm = "https://management.azure.com"
$token = (Get-AzAccessToken -ResourceUrl $arm).Token
$headers = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json"
}

function Invoke-ArmGet {
  param([Parameter(Mandatory)][string]$Uri)
  Invoke-RestMethod -Method GET -Uri $Uri -Headers $headers
}

function Get-FirstConsumptionOfferId {
  param([Parameter(Mandatory)][string]$SubscriptionId)

  # Look back 90 days for any usage rows
  $end = (Get-Date).ToString("yyyy-MM-dd")
  $start = (Get-Date).AddDays(-90).ToString("yyyy-MM-dd")

  # Use a stable API version for usageDetails
  $api = "2019-11-01"

  # Build a filter that many tenants accept
  $filter = [System.Web.HttpUtility]::UrlEncode("properties/usageStart ge '$start' and properties/usageEnd le '$end'")

  # $top=1 to keep it fast
  $uri = "$arm/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/usageDetails?api-version=$api&`$filter=$filter&`$top=1"

  try {
    $resp = Invoke-ArmGet -Uri $uri
    if ($resp.value -and $resp.value.Count -gt 0) {
      # usageDetails shape varies by commerce, but OfferId is often here when exposed
      $p = $resp.value[0].properties
      if ($p.offerId) { return $p.offerId }
      if ($p.OfferId) { return $p.OfferId }
    }
  } catch {
    # ignore and return null
  }

  return $null
}

$subs = Get-AzSubscription

$results = foreach ($sub in $subs) {

  $offerId = $null
  $source = $null

  # 1) Billing (fast path for PAYG, 10M, sponsorship, etc.)
  try {
    $billingUri = "$arm/providers/Microsoft.Billing/billingSubscriptions/$($sub.Id)?api-version=2024-04-01"
    $b = Invoke-ArmGet -Uri $billingUri
    $offerId = $b.properties.offerId
    if ($offerId) { $source = "Microsoft.Billing" }
  } catch {
    # NotFound or forbidden is common for VS benefit subs
  }

  # 2) Consumption fallback (common for Visual Studio / MVP)
  if (-not $offerId) {
    $offerId = Get-FirstConsumptionOfferId -SubscriptionId $sub.Id
    if ($offerId) { $source = "Microsoft.Consumption" }
  }

  if (-not $offerId) { $source = "NotExposedByPublicAPI" }

  [pscustomobject]@{
    SubscriptionName = $sub.Name
    SubscriptionId   = $sub.Id
    OfferId          = $offerId
    OfferSource      = $source
  }
}

$results |
Sort-Object OfferSource, SubscriptionName |
Format-Table -AutoSize
