<#
.SYNOPSIS
Prints all planned operations to screen, including a summary over each attribute and method

.EXAMPLE
$Operations | Show-UserWritebackOperation
#>
function Show-UserWritebackOperation {
    [CmdletBinding(SupportsShouldProcess = $true)]

    Param(
        # The operation to show
        [Parameter(ValueFromPipeline = $true)]
        $Operation,

        [Parameter()]
        [Switch] $Single
    )

    Begin {
        if (!$Single.IsPresent) {
            Write-Host "[group]Operations report"
        }

        $Methods = [ordered] @{
            "Set-ADUser"          = 0
            "Remove-ADUser"       = 0
            "New-ADUser"          = 0
            "Rename-ADObject"     = 0
            "Move-ADObject"       = 0
            "Patch Entra ID User" = 0
        }
    }

    Process {
        $Methods[$Operation.Action] += 1

        if ($Operation.Action -eq "Set-ADUser") {
            Write-Host "$($PSStyle.Foreground.Yellow)$($Operation.Action)$($PSStyle.Reset) $($Operation.Identity)"
            
            $Operation.Parameters.GetEnumerator() | ForEach-Object {
                if ($_.Key -eq "Replace") {
                    Write-Host " - $($_.Key):"
                    $_.Value.GetEnumerator() | ForEach-Object {
                        "    - {0,-30} : {1}" -f $_.Key, $_.Value | Write-Host
                    }
                }
                else {
                    " - {0,-30} : {1}" -f $_.Key, $_.Value | Write-Host
                }
            }
        }
        elseif ($Operation.Action -eq "New-ADUser") {
            Write-Host "$($PSStyle.Foreground.Green)$($Operation.Action)$($PSStyle.Reset) $($Operation.Identity)"

            $Operation.Parameters.GetEnumerator() | ForEach-Object {
                if ($_.Key -in "OtherAttributes") {
                    Write-Host " - $($_.Key):"
                    $_.Value.GetEnumerator() | ForEach-Object {
                        "    - {0,-30} : {1}" -f $_.Key, $_.Value | Write-Host
                    }
                }
                else {
                    " - {0,-30} : {1}" -f $_.Key, $_.Value | Write-Host
                }
            }
        }
        elseif ($Operation.Action -eq "Remove-ADUser") {
            Write-Host "$($PSStyle.Foreground.Red)$($Operation.Action)$($PSStyle.Reset) $($Operation.Identity)"
        }
        elseif ($Operation.Action -eq "Rename-ADObject") {
            Write-Host "$($PSStyle.Foreground.Yellow)$($Operation.Action)$($PSStyle.Reset) $($Operation.Identity)"
            $Operation.Parameters.GetEnumerator() | ForEach-Object {
                " - {0,-30} : {1}" -f $_.Key, $_.Value | Write-Host
            }
        }
        elseif ($Operation.Action -eq "Move-ADObject") {
            Write-Host "$($PSStyle.Foreground.Yellow)$($Operation.Action)$($PSStyle.Reset) $($Operation.Identity)"
            $Operation.Parameters.GetEnumerator() | ForEach-Object {
                " - {0,-30} : {1}" -f $_.Key, $_.Value | Write-Host
            }
        }
        elseif ($Operation.Action -eq "Patch Entra ID User") {
            Write-Host "$($PSStyle.Foreground.Cyan)$($Operation.Action)$($PSStyle.Reset) $($Operation.Identity)"

            $Operation.Parameters.GetEnumerator() | ForEach-Object {
                " - {0,-30} : {1}" -f $_.Key, $_.Value | Write-Host
            }
        } else {
            Write-Warning "Unknown operation action '$($Operation.Action)'."
        }
    }

    End {
        if (!$Single.IsPresent) {
            Write-Host "[endgroup]"
        
            Write-Host "Operations summary:"
            $Methods.GetEnumerator() | ForEach-Object {
                $Color = $PSStyle.Foreground.Green
                $Color = $_.Key -eq "Remove-ADUser" ? $PSStyle.Foreground.BrightRed : $Color
                $Color = $_.Key -eq "New-ADUser" ? $PSStyle.Foreground.BrightGreen : $Color
                $Color = $_.Key -eq "Set-ADUser" ? $PSStyle.Foreground.Yellow : $Color
                $Color = $_.Key -eq "Rename-ADObject" ? $PSStyle.Foreground.Magenta : $Color
                $Color = $_.Key -eq "Move-ADObject" ? $PSStyle.Foreground.Blue : $Color
                $Color = $_.Key -eq "Patch Entra ID User" ? $PSStyle.Foreground.Cyan : $Color

                Write-Host " - $($_.Value) x $($Color)$($_.Key)$($PSStyle.Reset)"
            }
        }
    }
}