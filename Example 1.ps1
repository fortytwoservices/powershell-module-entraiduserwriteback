Import-Module EntraIDAccessToken -Force
Import-Module .\Fortytwo.IAM.UserWriteback\ -Force

$cs ??= Read-Host -AsSecureString
Add-EntraIDClientSecretAccessTokenProfile `
    -TenantId "237098ae-0798-4cf9-a3a5-208374d2dcfd" `
    -ClientId "55ffa0ca-c74f-4344-bf0e-af56ff30f920" `
    -ClientSecret $cs
    
Connect-ChangeEmailAgent