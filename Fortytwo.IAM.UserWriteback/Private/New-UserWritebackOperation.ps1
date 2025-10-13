function New-UserWritebackOperation {
    [CmdletBinding()]

    Param(
        # The action to perform. Possible values are 'Create', 'Update', 'Delete'.
        [Parameter(Mandatory = $true)]
        [ValidateSet("Set-ADUser", "Remove-ADUser", "New-ADUser", "Rename-ADObject")]
        [string]$Action,

        # The user object from Entra ID.
        [Parameter(Mandatory = $false)]
        [object]$EntraIDUser,

        # The user object from Active Directory.
        [Parameter(Mandatory = $false)]
        [object]$ADUser,

        # A hashtable of parameters required for the operation.
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters
    )

    Process {
        return [PSCustomObject]@{
            Action      = $Action
            EntraIDUser = $EntraIDUser
            ADUser      = $ADUser
            Parameters  = $Parameters
        }
    }
}