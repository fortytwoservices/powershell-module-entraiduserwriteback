Import-Module EntraIDAccessToken -Force
Import-Module .\Fortytwo.IAM.UserWriteback\ -Force

$cs ??= Read-Host -AsSecureString
Add-EntraIDClientSecretAccessTokenProfile `
    -TenantId "237098ae-0798-4cf9-a3a5-208374d2dcfd" `
    -ClientId "55ffa0ca-c74f-4344-bf0e-af56ff30f920" `
    -ClientSecret $cs
    
Connect-UserWriteback `
    -GroupObjectId "e687aa72-455f-48f1-ade3-4232e8fa2849" `
    -DefaultDestinationOU "OU=User writeback,DC=groupsoa,DC=goodworkaround,DC=com" `
    -Verbose

$sAMAccountName = {
    [CmdletBinding()]
    Param(
        $EntraIDUser, 
        $ADUser
    ) 
    
    Process {
        if($EntraIDUser.onPremisesSamAccountName) {
            return $EntraIDUser.onPremisesSamAccountName
        } else {
            $Prefix = $EntraIDUser.UserPrincipalName.Split("@")[0]
            if($Prefix.Length -gt 20) {
                $Prefix = $Prefix.Substring(0,20)
            }
            return $Prefix -replace "^[^a-zA-Z]+", ""
        }
    } 
}

$Operations = Get-UserWritebackOperations -Verbose -Debug -AttributeOverrides @{
    sAMAccountName = $sAMAccountName
}

$Operations | Show-UserWritebackOperation