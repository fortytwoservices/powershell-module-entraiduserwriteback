<#
.DESCRIPTION
    Connects the UserWriteback module to Entra ID and Active Directory.

.SYNOPSIS
    Connects the UserWriteback module to Entra ID and Active Directory.

.EXAMPLE
    Import-Module EntraIDAccessToken
    Import-Module Fortytwo.IAM.UserWriteback

    Add-EntraIDClientSecretAccessTokenProfile `
        -TenantId "bb73082a-b74c-4d39-aec0-41c77d6f4850" `
        -ClientId "78f07963-ce55-4b23-b56a-2e13f2036d7f"

    Connect-UserWriteback
#>
function Connect-UserWriteback {
    [CmdletBinding()]

    Param(
        # Access token profile to use for authentication. the EntraIDAccessToken module must be installed and imported.
        [Parameter(Mandatory = $false)]
        [string]$AccessTokenProfile = "default"
    )

    Process {
        $Script:AccessTokenProfile = $AccessTokenProfile

        if (!(Get-EntraIDAccessToken | Get-EntraIDAccessTokenHasRoles -Roles "user.read.all", "user.readwrite.all" -Any)) {
            Write-Warning "The access token profile '$AccessTokenProfile' does not have the required role 'user.read.all' or 'user.readwrite.all'. Please ensure the profile is correct and has the necessary permissions."        
        }
    }
}