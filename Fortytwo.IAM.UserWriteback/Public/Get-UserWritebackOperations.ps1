function Get-UserWritebackOperations {
    [CmdletBinding()]

    Param()

    Process {
        # Get all users in the specified group from Entra ID
        Write-Verbose "Getting members of group with object ID '$Script:GroupObjectId' from Entra ID."
        $Users = @()
        $Uri = "https://graph.microsoft.com/v1.0/groups/$Script:GroupObjectId/members?`$select=id,displayName,userPrincipalName,onPremisesDistinguishedName,onPremisesUserPrincipalName,onPremisesSamAccountName,onPremisesSecurityIdentifier&`$top=999"

        do {
            $Response = Invoke-RestMethod -Uri $Uri -Method Get -Headers (Get-EntraIDAccessTokenHeader -Profile $Script:AccessTokenProfile)
            if ($Response.value) {
                $Users += $Response.value
            }
            $Uri = $Response.'@odata.nextLink'
        } while ($Uri)

        Write-Verbose "Found $($Users.Count) users in group with object ID '$Script:GroupObjectId'."
    }
}