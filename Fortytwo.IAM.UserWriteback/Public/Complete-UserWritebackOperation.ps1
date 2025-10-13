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
            New-ADUser -AccountPassword $Password @$Operation.Parameters
        }
    }
}