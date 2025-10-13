Import-Module ../powershell-module-EntraIDAccessToken/EntraIDAccessToken -Force
Import-Module .\Fortytwo.IAM.UserWriteback\ -Force

$cs ??= Read-Host -AsSecureString
Add-EntraIDClientSecretAccessTokenProfile `
    -TenantId "237098ae-0798-4cf9-a3a5-208374d2dcfd" `
    -ClientId "72004b2d-a082-4d29-b51d-85011dbdccb4" `
    -ClientSecret $cs
    
Connect-ChangeEmailAgent