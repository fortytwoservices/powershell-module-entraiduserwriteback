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

.EXAMPLE
    Connect-UserWriteback `
        -GroupObjectId "e687aa72-455f-48f1-ade3-4232e8fa2849" `
        -DefaultDestinationOU "OU=User writeback,DC=corp,DC=goodworkaround,DC=com" `
        -DisableExtensionAttributeMapping `
        -Verbose
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
        [string]$AccessTokenProfile = "default",

        # Disable extensionAttribute1-15 mapping from Entra ID to Active Directory. Useful if these attributes are not available in the on-premises AD schema.
        [Parameter(Mandatory = $false)]
        [Switch] $DisableExtensionAttributeMapping,

        # Skip all tests during connection. Not recommended, useful for pester testing
        [Parameter(Mandatory = $false)]
        [Switch] $SkipAllTests
    )

    Process {
        $Script:AccessTokenProfile = $AccessTokenProfile
        $Script:GroupObjectId = $GroupObjectId
        $Script:DefaultDestinationOU = $DefaultDestinationOU
        $Script:DisableExtensionAttributeMapping = $DisableExtensionAttributeMapping.IsPresent ?? $true

        if ($SkipAllTests.IsPresent) {
            Write-Warning "⚠️ Skipping all connection tests. Proceed with caution!"
            return
        }

        if (!(Get-EntraIDAccessToken -Profile $AccessTokenProfile | Get-EntraIDAccessTokenHasRoles -Roles "user.read.all", "User.ReadWrite.All" -Any)) {
            Write-Warning "The access token profile '$AccessTokenProfile' does not have the required role 'user.read.all' or 'User.ReadWrite.All'. Please ensure the profile is correct and has the necessary permissions."        
        }
        else {
            Write-Verbose "✅ The access token profile '$AccessTokenProfile' has the required role 'user.read.all' or 'User.ReadWrite.All'."
        }

        # Verify that we can read the group from Entra ID
        $Group = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/groups/$GroupObjectId" -Method Get -Headers (Get-EntraIDAccessTokenHeader -Profile $AccessTokenProfile) -Verbose:$false

        if (!$Group.id) {
            throw "Could not find group with object ID '$GroupObjectId' in Entra ID. Please verify the GroupObjectId parameter."
        }
        else {
            Write-Verbose "✅ Found group '$($Group.displayName)' with object ID '$GroupObjectId' in Entra ID."
        }

        # Verify that the default OU exists in Active Directory
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$DefaultDestinationOU'" -ErrorAction SilentlyContinue)) {
            throw "The specified DefaultDestinationOU '$DefaultDestinationOU' does not exist in Active Directory. Please verify the DefaultDestinationOU parameter."
        }
        else {
            Write-Verbose "✅ OU '$DefaultDestinationOU' exists in Active Directory."
        }
    }
}