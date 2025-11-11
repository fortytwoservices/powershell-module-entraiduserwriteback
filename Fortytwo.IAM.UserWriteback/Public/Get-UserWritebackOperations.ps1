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
        $Uri = "https://graph.microsoft.com/v1.0/groups/$Script:GroupObjectId/members/microsoft.graph.user?`$select=id,customSecurityAttributes,employeeid,employeetype,displayName,accountEnabled,givenName,surname,officeLocation,userPrincipalName,onPremisesDistinguishedName,onPremisesUserPrincipalName,onPremisesSamAccountName,onPremisesSecurityIdentifier,onPremisesDomainName,onPremisesExtensionAttributes,companyName,department,mobilePhone,jobtitle,city,mail&`$top=999&`$expand=manager(`$select=id,onPremisesDistinguishedName,onPremisesDomainName)"

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
        $Properties = @(
            "enabled", "DisplayName", "manager", "employeeid", "employeetype", "adminDescription", "UserPrincipalName", "SamAccountName", "DistinguishedName", "ObjectSID", "givenName", "sn", "company", "department", "office", "title", "mobile", "city", "mail"
        )

        if (!$Script:DisableExtensionAttributeMapping) {
            1..15 | ForEach-Object { $Properties += "extensionAttribute$_" }
        }

        $ADUsers = Get-ADUser -Filter * -Properties $Properties -ErrorAction Stop
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

            $AllCalculatedAttributes = @{
                path              = $AttributeOverrides.ContainsKey("path") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["path"] -ArgumentList $EntraIDUser, $ADUser) : $Script:DefaultDestinationOU
                name              = $AttributeOverrides.ContainsKey("name") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["name"] -ArgumentList $EntraIDUser, $ADUser) : $($EntraIDUser.userPrincipalName.Split("@")[0].replace(".", " "))
                sAMAccountName    = $AttributeOverrides.ContainsKey("sAMAccountName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["sAMAccountName"] -ArgumentList $EntraIDUser, $ADUser) : "NO-FLOW"
                userPrincipalName = $AttributeOverrides.ContainsKey("userPrincipalName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["userPrincipalName"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.UserPrincipalName
                givenName         = $AttributeOverrides.ContainsKey("givenName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["givenName"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.GivenName
                sn                = $AttributeOverrides.ContainsKey("sn") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["sn"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.Surname
                displayName       = $AttributeOverrides.ContainsKey("displayName") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["displayName"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.DisplayName
                mobile            = $AttributeOverrides.ContainsKey("mobile") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["mobile"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.mobilePhone
                company           = $AttributeOverrides.ContainsKey("company") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["company"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.companyName
                department        = $AttributeOverrides.ContainsKey("department") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["department"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.department
                title             = $AttributeOverrides.ContainsKey("title") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["title"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.jobTitle
                mail              = $AttributeOverrides.ContainsKey("mail") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["mail"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.mail
                city              = $AttributeOverrides.ContainsKey("city") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["city"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.city
                manager           = $null
                office            = $AttributeOverrides.ContainsKey("office") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["office"] -ArgumentList $EntraIDUser, $ADUser) : $EntraIDUser.officeLocation
                enabled           = $EntraIDUser.accountEnabled ?? $false
                employeeType      = $AttributeOverrides.ContainsKey("employeeType") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["employeeType"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.employeeType
                employeeId        = $AttributeOverrides.ContainsKey("employeeId") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["employeeId"] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.employeeId
            }

            if ($EntraIDUser.manager.onPremisesDistinguishedName) {
                if($ADUsersMap.ContainsKey($EntraIDUser.manager.onPremisesDistinguishedName)) {
                    Write-Debug "Resolved manager '$($EntraIDUser.manager.onPremisesDistinguishedName)' for user '$($EntraIDUser.userPrincipalName)' in AD."
                    $AllCalculatedAttributes["manager"] = $EntraIDUser.manager.onPremisesDistinguishedName
                } else {
                    Write-Warning "Manager '$($EntraIDUser.manager.onPremisesDistinguishedName)' of user '$($EntraIDUser.userPrincipalName)' not found in Active Directory. Skipping manager assignment."
                }
            }

            if (!$Script:DisableExtensionAttributeMapping) {
                1..15 | ForEach-Object {
                    $Attr = "extensionAttribute$_"
                    $AllCalculatedAttributes[$Attr] = $AttributeOverrides.ContainsKey($Attr) ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides[$Attr] -ArgumentList $EntraIDUser, $null) : $EntraIDUser.onPremisesExtensionAttributes.$Attr
                }
            }

            if (!$ADUser) {
                Write-Verbose "No matching AD user found for Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)). This user will be created in Active Directory."

                $Parameters = @{OtherAttributes = @{adminDescription = $adminDescription } }
                $AllCalculatedAttributes.GetEnumerator() | ForEach-Object {
                    if ($_.Value -ne "NO-FLOW") {
                        if ($_.Key -in "path", "name", "sAMAccountName", "userPrincipalName", "displayName", "mobilePhone", "company", "department", "title", "city", "manager", "office", "enabled") {
                            $Parameters[$_.Key] = $_.Value
                            return
                        }
                        if ($null -eq $_.Value) {
                            Write-Debug "Calculated attribute '$($_.Key)' for new user is null. It will not be set in Active Directory."
                            return
                        }
                        $Parameters.OtherAttributes[$_.Key] = $_.Value
                    }
                }

                New-UserWritebackOperation -Action New-ADUser -EntraIDUser $EntraIDUser -Parameters $Parameters
            }
            else {
                $Name = $AttributeOverrides.ContainsKey("name") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["name"] -ArgumentList $EntraIDUser, $ADUser) : $($EntraIDUser.userPrincipalName.Split("@")[0].replace(".", " "))
                if ($Name -cne $ADUser.Name -and $Name -ne "NO-FLOW") {
                    Write-Verbose "Attribute 'Name' differs between Entra ID user and AD user. Entra ID value: '$Name', AD value: '$($ADUser.Name)'. This attribute will be updated in Active Directory."
                    New-UserWritebackOperation -Action Rename-ADObject -EntraIDUser $EntraIDUser -ADUser $ADUser -Identity $ADUser.ObjectSID.ToString() -Parameters @{
                        NewName = $Name
                    }
                }
                else {
                    Write-Debug "Attribute 'Name' is the same between Entra ID user and AD user. Value: '$Name'."
                }

                $Path = $AttributeOverrides.ContainsKey("path") ? (Invoke-Command -NoNewScope -ScriptBlock $AttributeOverrides["path"] -ArgumentList $EntraIDUser, $ADUser) : $Script:DefaultDestinationOU
                $CurrentPath = "OU={0}" -f ($ADUser.DistinguishedName -split "OU=", 2)[1]
                if ($Path -ne $CurrentPath -and $Path -ne "NO-FLOW") {
                    Write-Verbose "The path differs between AD and the calculated value. The object will be moved."
                    New-UserWritebackOperation -Action Move-ADObject -EntraIDUser $EntraIDUser -ADUser $ADUser -Identity $ADUser.ObjectSID.ToString() -Parameters @{
                        TargetPath = $Path
                    }
                }
                else {
                    Write-Debug "The object $($ADUser.DistinguishedName) is already in the correct place."
                }

                Write-Verbose "Matching AD user found for Entra ID user $($EntraIDUser.userPrincipalName) ($($EntraIDUser.id)): $($ADUser.SamAccountName) ($($ADUser.ObjectSID))."

                $Parameters = @{}
                $AllCalculatedAttributes.GetEnumerator() | ForEach-Object {
                    $Key = $_.Key
                    if ($Key -in "path", "name") {
                        return
                    }

                    if ($_.Value -ne "NO-FLOW") {
                        if ($_.Value -ne $ADUser.$Key) {
                            Write-Verbose "Attribute '$Key' differs between the calculated value and the AD user. Calculated value: '$($_.Value)', AD value: '$($ADUser.$Key)'. This attribute will be updated in Active Directory."
                            if ($Key -in "sAMAccountName", "userPrincipalName", "displayName", "mobile", "company", "department", "title", "city", "manager", "office", "enabled") {
                                $Parameters[$Key] = $_.Value
                            }
                            else {
                                $Parameters.Replace ??= @{}
                                $Parameters.Replace[$Key] = $_.Value
                            }
                        }
                        else {
                            Write-Debug "Attribute '$Key' already has the correct calculated value of '$($_.Value)'."
                        }
                    }
                }

                if ($Parameters.Count -gt 0) {
                    New-UserWritebackOperation -Action Set-ADUser -EntraIDUser $EntraIDUser -ADUser $ADUser -Identity $ADUser.ObjectSID.ToString() -Parameters $Parameters
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