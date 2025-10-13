function Complete-UserWritebackOperation {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Operation
    )

    Process {
        if ($Operation.Action -eq "New-ADUser") {
            $Operation | Show-UserWritebackOperation -Single
            $Password = ConvertTo-SecureString -String (New-Guid).ToString() -AsPlainText -Force
            $Parameters = $Operation.Parameters
            $CreatedUser = New-ADUser -AccountPassword $Password @Parameters -Passthru

            if ($CreatedUser.distinguishedName) {
                Write-Verbose "Created new AD user '$($CreatedUser.SamAccountName)' with distinguished name '$($CreatedUser.DistinguishedName)'."

                # TODO: UPDATE ENTRA ID USER HERE?
            }
            else {
                Write-Warning "Failed to create new AD user with parameters: $($Parameters | Out-String)"
            }
        }
        elseif ($Operation.Action -eq "Set-ADUser") {
            $Operation | Show-UserWritebackOperation -Single
            $Parameters = $Operation.Parameters
            Set-ADUser -Identity $Operation.Identity @Parameters

            Write-Verbose "Updated AD user '$($Operation.Identity)'."
        }
        elseif ($Operation.Action -eq "Remove-ADUser") {
            $Operation | Show-UserWritebackOperation -Single
            Remove-ADUser -Identity $Operation.Identity -Confirm:$false

            Write-Verbose "Removed AD user '$($Operation.Identity)'."
        }
    }
}