function New-UserWritebackOperation {
    [CmdletBinding()]

    Param(
        # The action to perform. Possible values are 'Create', 'Update', 'Delete'.
        [Parameter(Mandatory = $true)]
        [ValidateSet("Set-ADUser", "Remove-ADUser", "New-ADUser", "Rename-ADObject", "Move-ADObject", "Patch Entra ID User")]
        [string]$Action,

        # The user object from Entra ID.
        [Parameter(Mandatory = $false)]
        [object]$EntraIDUser,

        # The user object from Active Directory.
        [Parameter(Mandatory = $false)]
        [object]$ADUser,

        # A hashtable of parameters required for the operation.
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters,

        # The identity of the object to operate on (e.g. sAMAccountName or DistinguishedName).
        [Parameter(Mandatory = $false)]
        [string]$Identity
    )

    Process {
        return [PSCustomObject]@{
            Identity    = $Identity
            Action      = $Action
            EntraIDUser = $EntraIDUser
            ADUser      = $ADUser
            Parameters  = $Parameters
        }
    }
}