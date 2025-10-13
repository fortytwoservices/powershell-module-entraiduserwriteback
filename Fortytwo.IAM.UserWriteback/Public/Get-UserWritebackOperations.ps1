function Get-UserWritebackOperations {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory = $false)]
        $AttributeOverrides = @{}
    )

    Process {
        #region Get all users in the specified group from Entra ID
        Write-Verbose "Getting members of group with object ID '$Script:GroupObjectId' from Entra ID."
        $EntraIDUsers = @()
        $Uri = "https://graph.microsoft.com/v1.0/groups/$Script:GroupObjectId/members?`$select=id,displayName,accountEnabled,givenName,surname,userPrincipalName,onPremisesDistinguishedName,onPremisesUserPrincipalName,onPremisesSamAccountName,onPremisesSecurityIdentifier&`$top=999"

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
            $EntraIDUser = $_
            $ADUser = $null
            if (!$ADUser -and $EntraIDUser.onPremisesSecurityIdentifier) {
                $ADUser = $ADUsersMap[$EntraIDUser.onPremisesSecurityIdentifier]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using onPremisesSecurityIdentifier."
                }
            }
            
            if (!$ADUser -and $EntraIDUser.onPremisesUserPrincipalName) {
                $ADUser = $ADUsersMap[$EntraIDUser.onPremisesUserPrincipalName]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using onPremisesUserPrincipalName."
                }
            }

            if (!$ADUser -and $EntraIDUser.onPremisesSamAccountName) {
                $ADUser = $ADUsersMap[$EntraIDUser.onPremisesSamAccountName]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using onPremisesSamAccountName."
                }
            }

            if (!$ADUser -and $EntraIDUser.userPrincipalName) {
                $ADUser = $ADUsersMap[$EntraIDUser.userPrincipalName]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using userPrincipalName."
                }
            }

            if (!$ADUser) {
                Write-Verbose "No matching AD user found for Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)). This user will be created in Active Directory."

                
                New-UserWritebackOperation -Action New-ADUser -EntraIDUser $EntraIDUser -Parameters @{
                    Name              = $AttributeOverrides.ContainsKey("name") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["name"] -ArgumentList $EntraIDUser, $null) : (New-Guid).ToString().Substring(0,18)
                    SamAccountName    = $AttributeOverrides.ContainsKey("sAMAccountName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["sAMAccountName"] -ArgumentList $EntraIDUser, $null) : (New-Guid).ToString().Substring(0,18)
                    UserPrincipalName = $AttributeOverrides.ContainsKey("userPrincipalName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["userPrincipalName"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.UserPrincipalName
                    GivenName         = $AttributeOverrides.ContainsKey("givenName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["givenName"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.GivenName
                    Surname           = $AttributeOverrides.ContainsKey("surname") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["surname"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.Surname
                    DisplayName       = $AttributeOverrides.ContainsKey("displayName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["displayName"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.DisplayName
                    Enabled           = $EntraIDUser.accountEnabled ?? $false
                }
            }
            else {
                Write-Verbose "Matching AD user found for Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)): $($ADUser.SamAccountName) ($($ADUser.ObjectSID))."
            }
        }
        #endregion
    }
}