function Complete-UserWritebackOperation {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Operation
    )

    Process {
        if($Operation.Action -eq "New-ADUser") {
            $Operation | Show-UserWritebackOperation -Single
            $Password = ConvertTo-SecureString -String (New-Guid).ToString() -AsPlainText -Force
            $Parameters = $Operation.Parameters
            $CreatedUser = New-ADUser -AccountPassword $Password @Parameters

            if($CreatedUser.DistinguishedName) {
                Write-Verbose "Created new AD user '$($CreatedUser.SamAccountName)' with distinguished name '$($CreatedUser.DistinguishedName)'."
            } else {
                Write-Warning "Failed to create new AD user with parameters: $($Parameters | Out-String)"
            }
        }
    }
}