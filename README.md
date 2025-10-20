# Documentation for module Fortytwo.IAM.UserWriteback

A module for synchronizing users from Entra ID into Active Directory, and writing onpremises* attributes back to Entra ID. Useful when certain users still require on-premises AD users, while all users have their SOA convert to Entra ID. 

## Installation

The module is published to the PowerShell gallery:

```PowerShell
Install-Module -Scope CurrentUser -Name Fortytwo.IAM.UserWriteback
```

## General

The module is invoked in three steps:

- Connect (```Connect-UserWriteback```) the module to Entra ID, which is using the [EntraIDAccesToken](https://www.powershellgallery.com/packages/EntraIDAccessToken) module.
- Get required operations (```Get-UserWritebackOperations```), which will return a list of operations that must be completed in order to have AD and Entra ID users have the correct attribute values.
- Complete the operations

## Examples

### Connect

The [```Connect-UserWriteback```](Documentation.md#connect-userwriteback) is used to tell the module which Entra ID group is used to determine the scoped users, and where to put users if the path attribute is not calculated.

```PowerShell
Connect-UserWriteback `
    -GroupObjectId "e687aa72-455f-48f1-ade3-4232e8fa2849" `
    -DefaultDestinationOU "OU=User writeback,DC=groupsoa,DC=goodworkaround,DC=com" `
    -DisableExtensionAttributeMapping `
    -Verbose
```

### Get and complete operations

```PowerShell
$Operations = Get-UserWritebackOperations -Verbose
$Operations | Show-UserWritebackOperation
Read-Host "Press enter to complete"
$Operations | Complete-UserWritebackOperation -Verbose
```

### Get and complete operations with custom attribute flow

```PowerShell
$path = {
    [CmdletBinding()]
    Param(
        $EntraIDUser, 
        $ADUser
    ) 
    
    Process {
        if ($EntraIDUser.givenName?.Split(" ")[0] -eq 'Alma') {
            return "OU=VIPs,OU=User writeback,DC=groupsoa,DC=goodworkaround,DC=com"
        }
        else {
            return "OU=User writeback,DC=groupsoa,DC=goodworkaround,DC=com"
        }
    } 
}

$Operations = Get-UserWritebackOperations -Verbose -AttributeOverrides @{
    path           = $path
}

$Operations | Show-UserWritebackOperation

if ($Operations.Count -eq 0) {
    Write-Host -ForegroundColor Yellow "No operations to perform."
    return
}

Read-Host "Press Enter to continue..."

$Operations | Complete-UserWritebackOperation -Verbose
```