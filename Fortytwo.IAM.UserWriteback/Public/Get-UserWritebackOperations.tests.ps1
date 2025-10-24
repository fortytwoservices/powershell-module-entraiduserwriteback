BeforeAll {
    Install-Module EntraIDAccessToken -Force -Scope CurrentUser
    Add-EntraIDExternalAccessTokenProfile -AccessToken "dummy"
    $Script:Module = Import-Module "$PSScriptRoot/../" -Force -PassThru
    
    function Get-ADUser {
        Param(
            $Filter,
            $Identity,
            $Properties
        )

        return
    }
}
    
Describe "Get-UserWritebackOperations" {
    BeforeAll {
        Connect-UserWriteback -GroupObjectId "test-group-id" -DefaultDestinationOU "OU=Default created users,DC=example,DC=com" -DisableExtensionAttributeMapping -SkipAllTests

        # Mocking dependencies
        Mock -ModuleName $Script:Module.Name -CommandName Get-ADUser -MockWith {
            return @(
                [PSCustomObject]@{ 
                    SamAccountName    = "jdoe"
                    DistinguishedName = "CN=John M. Doe,OU=Users,DC=example,DC=com"
                    UserPrincipalName = "jdoe@example.com"
                    DisplayName       = "John M. Doe"
                    GivenName         = "John"
                    sn                = "Doe"
                    mail              = "jdoe@example.com"
                    enabled           = $true
                    manager           = $null
                    employeeid        = "12345"
                    employeetype      = "Part-Time"
                    adminDescription  = "userwriteback_8cc09d76-fbfd-42ea-a4ab-d3cee31c48f6"
                    ObjectSID         = "S-1-5-21-3623811015-3361044348-30300820-1013"
                    company           = "Fortytwo Test"
                    department        = "Cloud Operations"
                    office            = "OSL"
                    title             = "Principal Engineer"
                    mobile            = "1234567810"
                    city              = "Oslo"
                }

                [PSCustomObject]@{ 
                    SamAccountName    = "jsmith"
                    DistinguishedName = "CN=John Smith,OU=Users,DC=example,DC=com"
                    UserPrincipalName = "jsmith@example.com"
                    DisplayName       = "John Smith"
                    GivenName         = "John"
                    sn                = "Smith"
                    mail              = "jsmith@example.com"
                    enabled           = $true
                    manager           = $null
                    employeeid        = "12346"
                    employeetype      = "Full-Time"
                    adminDescription  = "userwriteback_2bb59887-3117-4d63-84f2-a8232315086f"
                    ObjectSID         = "S-1-5-21-3623811015-3361044348-30300820-1014"
                    company           = "Fortytwo"
                    department        = "Cloud Services"
                    office            = "BRD"
                    title             = "Principal Engineer"
                    mobile            = "1234567811"
                    city              = "Brumunddal"
                }
            )
        }

        Mock -ModuleName $Script:Module.Name -CommandName Invoke-RestMethod -MockWith {
            Write-Warning "Mocked Invoke-RestMethod called with URI: $($PSBoundParameters.Uri)"
            return @{value = @(
                    [PSCustomObject]@{ 
                        id                            = "8cc09d76-fbfd-42ea-a4ab-d3cee31c48f6"
                        customSecurityAttributes      = $null
                        employeeid                    = "12345"
                        employeetype                  = "Full-Time"
                        displayName                   = "John Doe"
                        accountEnabled                = $true
                        givenName                     = "John"
                        surname                       = "Doe"
                        officeLocation                = "BRD"
                        userPrincipalName             = "jdoe@example.com"
                        onPremisesDistinguishedName   = $null
                        onPremisesUserPrincipalName   = $null
                        onPremisesSamAccountName      = $null
                        onPremisesSecurityIdentifier  = "S-1-5-21-3623811015-3361044348-30300820-1013"
                        onPremisesDomainName          = $null
                        onPremisesExtensionAttributes = @{}
                        manager                       = @{
                            id                          = "2bb59887-3117-4d63-84f2-a8232315086f"
                            onPremisesDistinguishedName = "CN=John Smith,OU=Users,DC=example,DC=com"
                        }
                        companyName                   = "Fortytwo"
                        department                    = "Cloud Services"
                        mobilePhone                   = "1234567810"
                        jobtitle                      = "Principal Engineer"
                        city                          = "Brumunddal"
                        mail                          = "jdoe@example.com"
                    }

                    [PSCustomObject]@{ 
                        id                            = "2bb59887-3117-4d63-84f2-a8232315086f"
                        customSecurityAttributes      = $null
                        employeeid                    = "12346"
                        employeetype                  = "Full-Time"
                        displayName                   = "John Smith"
                        accountEnabled                = $false
                        givenName                     = "John"
                        surname                       = "Smith"
                        officeLocation                = "BRD"
                        userPrincipalName             = "jsmith@example.com"
                        onPremisesDistinguishedName   = "CN=John Smith,OU=Users,DC=example,DC=com"
                        onPremisesUserPrincipalName   = "jsmith@example.com"
                        onPremisesSamAccountName      = "jsmith"
                        onPremisesSecurityIdentifier  = "S-1-5-21-3623811015-3361044348-30300820-1014"
                        onPremisesDomainName          = "example.com"
                        onPremisesExtensionAttributes = @{}
                        companyName                   = "Fortytwo"
                        department                    = "Cloud Services"
                        mobilePhone                   = "1234567811"
                        jobtitle                      = "Principal Engineer"
                        city                          = "Brumunddal"
                        mail                          = "jsmith@example.com"
                    }

                    [PSCustomObject]@{ 
                        id                            = "dddabf44-0803-4838-b211-129ad0769c53"
                        customSecurityAttributes      = $null
                        employeeid                    = "12347"
                        employeetype                  = "Full-Time"
                        displayName                   = "Bon Jovi"
                        accountEnabled                = $true
                        givenName                     = "Bon"
                        surname                       = "Jovi"
                        officeLocation                = "BRD"
                        userPrincipalName             = "bon.jovi@example.com"
                        onPremisesDistinguishedName   = $null
                        onPremisesUserPrincipalName   = $null
                        onPremisesSamAccountName      = $null
                        onPremisesSecurityIdentifier  = $null
                        onPremisesDomainName          = $null
                        onPremisesExtensionAttributes = @{}
                        companyName                   = "Fortytwo"
                        department                    = "Cloud Services"
                        mobilePhone                   = "1234567812"
                        jobtitle                      = "Principal Engineer"
                        city                          = "Brumunddal"
                        mail                          = "bon.jovi@example.com"
                    }
                )
            }
        }

        $Operations = Get-UserWritebackOperations -Verbose -Debug
        # $Operations | ConvertTo-Json | Write-Host -ForegroundColor Yellow
    }

    It "Should have existing AD user set correctly for jdoe" {
        $Operation = $Operations | Where-Object Action -eq "Set-ADUser" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.ADUser.SamAccountName | Should -Be "jdoe"
        $Operation.ADUser.DistinguishedName | Should -Be "CN=John M. Doe,OU=Users,DC=example,DC=com"
    }

    It "Should have existing Entra user set correctly for jdoe" {
        $Operation = $Operations | Where-Object Action -eq "Set-ADUser" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.EntraIDUser.id | Should -Be "8cc09d76-fbfd-42ea-a4ab-d3cee31c48f6"
        $Operation.EntraIDUser.mail | Should -Be "jdoe@example.com"
    }

    It "Should have a planned operation for updating company for jdoe" {
        $Operation = $Operations | Where-Object Action -eq "Set-ADUser" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.Parameters.company | Should -Be "Fortytwo"
    }

    It "Should have a planned operation for updating department for jdoe" {
        $Operation = $Operations | Where-Object Action -eq "Set-ADUser" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.Parameters.department | Should -Be "Cloud Services"
    }

    It "Should have a planned operation for updating office for jdoe" {
        $Operation = $Operations | Where-Object Action -eq "Set-ADUser" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.Parameters.office | Should -Be "BRD"
    }

    It "Should have a planned operation for updating city for jdoe" {
        $Operation = $Operations | Where-Object Action -eq "Set-ADUser" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.Parameters.city | Should -Be "Brumunddal"
    }

    It "Should have a planned operation for updating displayName for jdoe" {
        $Operation = $Operations | Where-Object Action -eq "Set-ADUser" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.Parameters.displayName | Should -Be "John Doe"
    }

    It "Should have a planned operation for updating manager for jdoe" {
        $Operation = $Operations | Where-Object Action -eq "Set-ADUser" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.Parameters.manager | Should -Be "CN=John Smith,OU=Users,DC=example,DC=com"
    }

    It "Should have a planned operation for updating employeetype for jdoe" {
        $Operation = $Operations | Where-Object Action -eq "Set-ADUser" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.Parameters.replace.employeetype | Should -Be "Full-Time"
    }

    It "Should have a planned operation for renaming jdoe's cn to the upn of the user" {
        $Operation = $Operations | Where-Object Action -eq "Rename-ADObject" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.Parameters.NewName | Should -Be "jdoe@example.com"
    }

    It "Should have a planned operation for moving jdoe to the default OU" {
        $Operation = $Operations | Where-Object Action -eq "Move-ADObject" | Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1013"
        $Operation.Parameters.TargetPath | Should -Be "OU=Default created users,DC=example,DC=com"
    }

    It "Should have planned operation for disabling jsmith" {
        $Operation = $Operations | 
        Where-Object Action -eq "Set-ADUser" | 
        Where-Object Identity -eq "S-1-5-21-3623811015-3361044348-30300820-1014" |
        Where-Object { $_.Parameters.enabled -ne $null }
        
        $Operation.Parameters.enabled | Should -Be $false
    }

    It "Should have a planned operation to update jdoe with onPremisesDistinguishedName" {
        $Operation = $Operations | Where-Object Action -eq "Patch Entra ID User" | Where-Object Identity -eq "8cc09d76-fbfd-42ea-a4ab-d3cee31c48f6"
        $Operation.Parameters.onPremisesDistinguishedName | Should -Be "CN=John M. Doe,OU=Users,DC=example,DC=com"
    }

    It "Should have a planned operation to update jdoe with onPremisesDomainName" {
        $Operation = $Operations | Where-Object Action -eq "Patch Entra ID User" | Where-Object Identity -eq "8cc09d76-fbfd-42ea-a4ab-d3cee31c48f6"
        $Operation.Parameters.onPremisesDomainName | Should -Be "example.com"
    }

    It "Should have a planned operation to update jdoe with onPremisesUserPrincipalName" {
        $Operation = $Operations | Where-Object Action -eq "Patch Entra ID User" | Where-Object Identity -eq "8cc09d76-fbfd-42ea-a4ab-d3cee31c48f6"
        $Operation.Parameters.onPremisesUserPrincipalName | Should -Be "jdoe@example.com"
    }

    It "Should have a planned operation to update jdoe with onPremisesSamAccountName" {
        $Operation = $Operations | Where-Object Action -eq "Patch Entra ID User" | Where-Object Identity -eq "8cc09d76-fbfd-42ea-a4ab-d3cee31c48f6"
        $Operation.Parameters.onPremisesSamAccountName | Should -Be "jdoe"
    }

    It "Should be no operation for jsmith to update on-premises attributes since they are already set" {
        $Operation = $Operations | Where-Object Action -eq "Patch Entra ID User" | Where-Object Identity -eq "2bb59887-3117-4d63-84f2-a8232315086f"
        $Operation | Should -Be $null
    }

    It "Should have a planned operation to create Bon Jovi" {
        $Operation = $Operations | Where-Object Action -eq "New-ADUser" | Where-Object { $_.EntraIDUser.id -eq "dddabf44-0803-4838-b211-129ad0769c53" }
        $Operation | Should -Not -Be $null

        $Operation.Parameters.SamAccountName | Should -Be $null
        $Operation.Parameters.UserPrincipalName | Should -Be "bon.jovi@example.com"
    }

    It "Should be no plan to patch entra id user for bon jovi" {
        $Operation = $Operations | Where-Object Action -eq "Patch Entra ID User" | Where-Object Identity -eq "dddabf44-0803-4838-b211-129ad0769c53"
        $Operation | Should -Be $null
    }
}