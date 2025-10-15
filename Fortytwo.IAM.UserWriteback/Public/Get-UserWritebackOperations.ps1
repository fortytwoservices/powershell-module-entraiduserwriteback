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
        $Uri = "https://graph.microsoft.com/v1.0/groups/$Script:GroupObjectId/members/microsoft.graph.user?`$select=id,displayName,accountEnabled,givenName,surname,userPrincipalName,onPremisesDistinguishedName,onPremisesUserPrincipalName,onPremisesSamAccountName,onPremisesSecurityIdentifier,onPremisesDomainName,companyName,department,mobilePhone,jobtitle&`$top=999&`$expand=manager(`$select=id,onPremisesDistinguishedName,onPremisesDomainName)"

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
        $ADUsers = Get-ADUser -Filter * -Properties enabled, DisplayName, adminDescription, UserPrincipalName, SamAccountName, DistinguishedName, ObjectSID, givenName, sn, company, department, physicalDeliveryOfficeName, title, mail, mobilephone
        $ADUsersMap = @{}
        foreach ($ADUser in $ADUsers) {
            $ADUsersMap[$ADUser.ObjectSID.ToString()] = $ADUser
            $ADUsersMap[$ADUser.DistinguishedName] = $ADUser
            if ($ADUser.UserPrincipalName) {
                $ADUsersMap[$ADUser.UserPrincipalName] = $ADUser
            }
            if ($ADUser.adminDescription -and $ADUser.adminDescription -like "userwriteback_*") {
                $ADUsersMap[$ADUser.adminDescription] = $ADUser
            }
        }
        Write-Verbose "Found $($ADUsers.Count) users in Active Directory."
        #endregion

        #region Join users from Entra ID and Active Directory and calculate required operations
        $EntraIDUsers | ForEach-Object {
            $EntraIDUser = $_
            $ADUser = $null
            $adminDescription = "userwriteback_$($EntraIDUser.id)"
            
            if (!$ADUser) {
                $ADUser = $ADUsersMap[$adminDescription]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using adminDescription."
                }
            }

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

            if (!$ADUser -and $EntraIDUser.userPrincipalName) {
                $ADUser = $ADUsersMap[$EntraIDUser.userPrincipalName]
                if ($ADUser) {
                    Write-Debug "Joined Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)) with AD user $($ADUser.SamAccountName) ($($ADUser.ObjectSID)) using userPrincipalName."
                }
            }

            if (!$ADUser) {
                Write-Verbose "No matching AD user found for Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)). This user will be created in Active Directory."

                New-UserWritebackOperation -Action New-ADUser -EntraIDUser $EntraIDUser -Parameters @{
                    Path              = $AttributeOverrides.ContainsKey("path") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["path"] -ArgumentList $EntraIDUser, $null) : $Script:DefaultDestinationOU
                    Name              = $AttributeOverrides.ContainsKey("name") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["name"] -ArgumentList $EntraIDUser, $null) : (New-Guid).ToString().Substring(0, 18)
                    SamAccountName    = $AttributeOverrides.ContainsKey("sAMAccountName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["sAMAccountName"] -ArgumentList $EntraIDUser, $null) : (New-Guid).ToString().Substring(0, 18)
                    UserPrincipalName = $AttributeOverrides.ContainsKey("userPrincipalName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["userPrincipalName"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.UserPrincipalName
                    GivenName         = $AttributeOverrides.ContainsKey("givenName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["givenName"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.GivenName
                    Surname           = $AttributeOverrides.ContainsKey("surname") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["surname"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.Surname
                    DisplayName       = $AttributeOverrides.ContainsKey("displayName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["displayName"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.DisplayName
                    MobilePhone       = $AttributeOverrides.ContainsKey("mobilePhone") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["mobilePhone"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.mobilePhone
                    Company           = $AttributeOverrides.ContainsKey("company") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["company"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.companyName
                    Department        = $AttributeOverrides.ContainsKey("department") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["department"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.department
                    Title             = $AttributeOverrides.ContainsKey("title") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["title"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.jobTitle
                    Enabled           = $EntraIDUser.accountEnabled ?? $false
                    OtherAttributes   = @{
                        adminDescription = $adminDescription # Store the Entra ID user ID in adminDescription for tracking purposes
                    }
                }
            }
            else {
                Write-Verbose "Matching AD user found for Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)): $($ADUser.SamAccountName) ($($ADUser.ObjectSID))."

                $CalculatedActiveDirectoryAttributes = @{
                    UserPrincipalName = $AttributeOverrides.ContainsKey("userPrincipalName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["userPrincipalName"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.UserPrincipalName
                    GivenName         = $AttributeOverrides.ContainsKey("givenName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["givenName"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.GivenName
                    Surname           = $AttributeOverrides.ContainsKey("surname") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["surname"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.Surname
                    DisplayName       = $AttributeOverrides.ContainsKey("displayName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["displayName"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.DisplayName
                    MobilePhone       = $AttributeOverrides.ContainsKey("mobilePhone") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["mobilePhone"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.mobilePhone
                    Company           = $AttributeOverrides.ContainsKey("company") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["company"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.companyName
                    Department        = $AttributeOverrides.ContainsKey("department") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["department"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.department
                    Title             = $AttributeOverrides.ContainsKey("title") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["title"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.jobTitle
                    Manager           = if ($EntraIDUser.manager -and $EntraIDUser.manager.onPremisesDistinguishedName -and $EntraIDUser.onPremisesDomainName -eq $EntraIDUser.manager.onPremisesDomainName) { $EntraIDUser.manager.onPremisesDistinguishedName } else { $null }
                    Enabled           = $EntraIDUser.accountEnabled ?? $false
                }

                $ActiveDirectoryAttributeUpdates = @{}
                $CalculatedActiveDirectoryAttributes.GetEnumerator() | ForEach-Object {
                    $Key = $_.Key
                    $Value = $_.Value
                    if ($ADUser.$Key -ne $Value) {
                        Write-Verbose "Attribute '$Key' differs between Entra ID user and AD user. Entra ID value: '$Value', AD value: '$($ADUser.$Key)'. This attribute will be updated in Active Directory."
                        $ActiveDirectoryAttributeUpdates[$Key] = $Value
                    }
                    else {
                        Write-Debug "Attribute '$Key' is the same between Entra ID user and AD user. Value: '$Value'."
                    }
                }

                if ($ActiveDirectoryAttributeUpdates.Count -gt 0) {
                    New-UserWritebackOperation -Action Set-ADUser -EntraIDUser $EntraIDUser -ADUser $ADUser -Identity $ADUser.ObjectSID.ToString() -Parameters $ActiveDirectoryAttributeUpdates
                }
                else {
                    Write-Verbose "No attribute updates required for AD user '$($ADUser.SamAccountName)'."
                }

                $CalculatedEntraIDAttributes = @{
                    onPremisesDistinguishedName  = $ADUser.DistinguishedName
                    onPremisesSamAccountName     = $ADUser.SamAccountName
                    onPremisesUserPrincipalName  = $ADUser.UserPrincipalName
                    onPremisesSecurityIdentifier = $ADUser.ObjectSID.ToString()
                    onPremisesDomainName         = ($ADUser.DistinguishedName.Split(",") | Where-Object { $_ -like "DC=*" } | ForEach-Object { $_.Substring(3) }) -join "."
                }

                $EntraIDAttributeUpdates = @{}
                $CalculatedEntraIDAttributes.GetEnumerator() | ForEach-Object {
                    $Key = $_.Key
                    $Value = $_.Value
                    if ($EntraIDUser.$Key -ne $Value) {
                        Write-Warning "Attribute '$Key' differs between AD user and Entra ID user. AD value: '$Value', Entra ID value: '$($EntraIDUser.$Key)'. Please update this attribute in Entra ID."
                        $EntraIDAttributeUpdates[$Key] = $Value
                    }
                    else {
                        Write-Debug "Attribute '$Key' is the same between AD user and Entra ID user. Value: '$Value'."
                    }
                }

                if ($EntraIDAttributeUpdates.Count -gt 0) {
                    Write-Verbose "Entra ID user '$($EntraIDUser.userPrincipalName)' ($($EntraIDUser.id)) needs updates"
                    New-UserWritebackOperation -Action "Patch Entra ID User" -EntraIDUser $EntraIDUser -ADUser $ADUser -Identity $EntraIDUser.id -Parameters $EntraIDAttributeUpdates
                }
                else {
                    Write-Debug "No attribute updates required for Entra ID user '$($EntraIDUser.userPrincipalName)'."
                }
            }
        }
        #endregion

        #region
        # Find AD users that are not in the Entra ID group and need to be disabled
        $EntraIDUserMap = $EntraIDUsers | Where-Object { $_.onPremisesSecurityIdentifier } | Group-Object -AsHashTable -Property onPremisesSecurityIdentifier
        $EntraIDUserMap ??= @{}

        $ADUsers | 
        Where-Object adminDescription -like "userwriteback_*" | 
        ForEach-Object {
            $ADUser = $_
            if (-not $EntraIDUserMap.ContainsKey($ADUser.ObjectSID.ToString())) {
                Write-Verbose "AD user '$($ADUser.SamAccountName)' ($($ADUser.ObjectSID)) is not in the Entra ID group and will be disabled in Active Directory."

                if ($ADUser.Enabled -eq $false) {
                    Write-Debug "AD user '$($ADUser.SamAccountName)' ($($ADUser.ObjectSID)) is already disabled in Active Directory. No action required."
                    return
                }

                New-UserWritebackOperation -Action Set-ADUser -ADUser $ADUser -Identity $ADUser.ObjectSID.ToString() -Parameters @{
                    Enabled = $false
                }
            }
        }
        #endregion
    }
}