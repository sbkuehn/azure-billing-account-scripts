<# 
.SYNOPSIS
Classifies Azure subscriptions by commercial billing model using modern Azure billing reality.

.DESCRIPTION
This script enumerates all subscriptions visible to the current user and classifies each
subscription into a CommercialModel based on:
- Billing agreement metadata when available (EA, MCA/Azure Plan, CSP)
- Legacy billing models (MOSP)
- Program-based benefit subscriptions (MVP, MSDN, Sponsorship, Partner)
- System subscriptions

Offer IDs are intentionally NOT used because they are deprecated and not consistently
exposed for modern Azure billing.

.AUTHOR
Shannon Eldridge-Kuehn
#>

# Prerequisites:
# Connect-AzAccount
# Set-AzContext -Subscription <any subscription in the target tenant>

$results = @()

$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {

    $commercialModel = $null

    try {
        # EA and MCA subscriptions return billing metadata here
        $billingSub = Get-AzBillingSubscription -SubscriptionId $sub.Id -ErrorAction Stop

        if ($billingSub.BillingAccountAgreementType -eq "EnterpriseAgreement") {
            $commercialModel = "Enterprise Agreement"
        }
        elseif ($billingSub.BillingAccountAgreementType -eq "MicrosoftCustomerAgreement") {
            if ($billingSub.BillingAccountType -eq "Customer") {
                $commercialModel = "PAYG (Azure Plan / MCA)"
            }
            elseif ($billingSub.BillingAccountType -eq "Partner") {
                $commercialModel = "CSP (Azure Plan)"
            }
            else {
                $commercialModel = "Azure Plan (Unknown Motion)"
            }
        }
        else {
            $commercialModel = "Unknown Billing Agreement"
        }
    }
    catch {
        # No billing metadata available: infer commercial intent
        switch -Regex ($sub.Name) {
            'MVP' {
                $commercialModel = 'MVP Benefit'
                break
            }
            'Visual Studio|Dev/Test|MSDN' {
                $commercialModel = 'DevTest Benefit'
                break
            }
            'Sponsorship' {
                $commercialModel = 'Azure Sponsorship'
                break
            }
            'MPN|MCT|MCPP' {
                $commercialModel = 'Partner Benefit'
                break
            }
            'PAYG|10M' {
                $commercialModel = 'Legacy PAYG (MOSP)'
                break
            }
            default {
                $commercialModel = 'System or Unknown Subscription'
            }
        }
    }

    $results += [PSCustomObject]@{
        SubscriptionName = $sub.Name
        SubscriptionId   = $sub.Id
        TenantId         = $sub.TenantId
        CommercialModel  = $commercialModel
    }
}

$results |
    Sort-Object CommercialModel, SubscriptionName |
    Format-Table -AutoSize
