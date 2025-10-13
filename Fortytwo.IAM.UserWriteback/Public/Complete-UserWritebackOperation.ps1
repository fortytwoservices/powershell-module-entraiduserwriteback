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
            New-ADUser -AccountPassword $Password @Parameters
        }
    }
}