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
        # The object ID of the group in Entra ID that contains the users to write back to Active Directory.
        [Parameter(Mandatory = $true)]
        [string] $GroupObjectId,

        # The OU used for the writeback operations, if no OU is defined on the user.
        [Parameter(Mandatory = $true)]
        [string] $DefaultDestinationOU,

        # Access token profile to use for authentication. the EntraIDAccessToken module must be installed and imported.
        [Parameter(Mandatory = $false)]
        [string]$AccessTokenProfile = "default"
    )

    Process {
        $Script:AccessTokenProfile = $AccessTokenProfile
        $Script:GroupObjectId = $GroupObjectId
        $Script:DefaultDestinationOU = $DefaultDestinationOU

        if (!(Get-EntraIDAccessToken | Get-EntraIDAccessTokenHasRoles -Roles "user.read.all", "user.readwrite.all" -Any)) {
            Write-Warning "The access token profile '$AccessTokenProfile' does not have the required role 'user.read.all' or 'user.readwrite.all'. Please ensure the profile is correct and has the necessary permissions."        
        }

        # Verify that we can read the group from Entra ID
        $Group = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/groups/$GroupObjectId" -Method Get -Headers (Get-EntraIDAccessTokenHeader -Profile $AccessTokenProfile)

        if(!$Group.id) {
            throw "Could not find group with object ID '$GroupObjectId' in Entra ID. Please verify the GroupObjectId parameter."
        }

        # Verify that the default OU exists in Active Directory
        if(-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$DefaultDestinationOU'" -ErrorAction SilentlyContinue)) {
            throw "The specified DefaultDestinationOU '$DefaultDestinationOU' does not exist in Active Directory. Please verify the DefaultDestinationOU parameter."
        }
    }
}