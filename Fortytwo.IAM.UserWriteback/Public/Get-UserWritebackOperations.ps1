function Get-UserWritebackOperations {
    [CmdletBinding()]

    Param()

    Process {
        #region Get all users in the specified group from Entra ID
        Write-Verbose "Getting members of group with object ID '$Script:GroupObjectId' from Entra ID."
        $EntraIDUsers = @()
        $Uri = "https://graph.microsoft.com/v1.0/groups/$Script:GroupObjectId/members?`$select=id,displayName,userPrincipalName,onPremisesDistinguishedName,onPremisesUserPrincipalName,onPremisesSamAccountName,onPremisesSecurityIdentifier&`$top=999"

        do {
            $Response = Invoke-RestMethod -Uri $Uri -Method Get -Headers (Get-EntraIDAccessTokenHeader -Profile $Script:AccessTokenProfile)
            if ($Response.value) {
                $EntraIDUsers += $Response.value
            }
            $Uri = $Response.'@odata.nextLink'
        } while ($Uri)

        if (!$EntraIDUsers) {
            Write-Error "No users found in group with object ID '$Script:GroupObjectId' in Entra ID."
            return @()
        }

        Write-Verbose "Found $($EntraIDUsers.Count) users in group with object ID '$Script:GroupObjectId'."
        #endregion

        #region Get all users from Active Directory
        Write-Verbose "Getting all users from Active Directory."
        $ADUsers = Get-ADUser -Filter * -Properties DisplayName, UserPrincipalName, SamAccountName, DistinguishedName, ObjectSID
        $ADUsersMap = @{}
        foreach ($ADUser in $ADUsers) {
            $ADUsersMap[$ADUser.ObjectSID.ToString()] = $ADUser
            if ($ADUser.UserPrincipalName) {
                $ADUsersMap[$ADUser.UserPrincipalName] = $ADUser
            }
        }
        Write-Verbose "Found $($ADUsers.Count) users in Active Directory."
        #endregion

        #region Join users from Entra ID and Active Directory and calculate required operations
        $EntraIDUsers | ForEach-Object {
            $ADUser = $null
            if (!$ADUser -and $_.onPremisesSecurityIdentifier) {
                $ADUser = $ADUsersMap[$_.onPremisesSecurityIdentifier]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($_.userPrincipalName) ($($_.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using onPremisesSecurityIdentifier."
                }
            }
            
            if (!$ADUser -and $_.onPremisesUserPrincipalName) {
                $ADUser = $ADUsersMap[$_.onPremisesUserPrincipalName]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($_.userPrincipalName) ($($_.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using onPremisesUserPrincipalName."
                }
            }

            if (!$ADUser -and $_.onPremisesSamAccountName) {
                $ADUser = $ADUsersMap[$_.onPremisesSamAccountName]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($_.userPrincipalName) ($($_.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using onPremisesSamAccountName."
                }
            }

            if (!$ADUser -and $_.userPrincipalName) {
                $ADUser = $ADUsersMap[$_.userPrincipalName]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($_.userPrincipalName) ($($_.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using userPrincipalName."
                }
            }

            if (!$ADUser) {
                Write-Verbose "No matching AD user found for Entra ID user $($_.userPrincipalName) ($($_.id)). This user will be created in Active Directory."
            }
            else {
                Write-Verbose "Matching AD user found for Entra ID user $($_.userPrincipalName) ($($_.id)): $($ADUser.SamAccountName) ($($ADUser.ObjectSID))."
            }
        }
        #endregion
    }
}