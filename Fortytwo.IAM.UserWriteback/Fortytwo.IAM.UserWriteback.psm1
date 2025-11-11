# Inspiration: https://github.com/RamblingCookieMonster/PSStackExchange/blob/master/PSStackExchange/PSStackExchange.psm1

# To be able to override default server and credential parameters in cmdlets like Get-ADUser, we need to
# preserve the global PSDefaultParameterValues and re-apply them to the script scope.
$script:PSDefaultParameterValues = $global:PSDefaultParameterValues

New-Variable -Scope Script -Name AccessTokenProfile -Value "default"
New-Variable -Scope Script -Name DefaultDestinationOU -Value $null

# Get public and private function definition files.
$Private = (Test-Path $PSScriptRoot\Private) ? @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue ) : @()
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue -Exclude "*.tests.*" )

# Dot source the files in order to define all cmdlets
Foreach ($import in @($Public + $Private)) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

# Export all functions
Export-ModuleMember -Function $Public.Basename