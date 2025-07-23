<#
.SYNOPSIS
    Interactive tool to change a single user’s email/UPN *or* bulk‑rename many users from a CSV.
.DESCRIPTION
    • Prompts for either a single rename or a CSV path containing OldEmail,NewEmail.
    • Updates both UserPrincipalName and mail attributes on‑prem AD.
    • Triggers Azure AD Connect delta sync when done (optional).
    • Logs results to screen and to Rename‑Log.csv.
.NOTES
    Requires: ActiveDirectory module, Azure AD Connect (for sync).
    Written July 2025.
#>

#----- 0. Safety checks ---------------------------------------------------------
if (-not (Get-Module -ListAvailable ActiveDirectory)) {
    Write-Warning "ActiveDirectory module is missing. Install RSAT Tools first."
    return
}
Import-Module ActiveDirectory

# Helper to rename a single account
function Rename-AdUserEmail {
    param(
        [Parameter(Mandatory)][string]$OldEmail,
        [Parameter(Mandatory)][string]$NewEmail
    )
    $user = Get-ADUser -Filter "UserPrincipalName -eq '$OldEmail'" `
              -Properties SamAccountName, UserPrincipalName, mail  -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Host "✖  $OldEmail not found in AD" -ForegroundColor Red
        return
    }

    # 1) Change UPN
    Set-ADUser -Identity $user.SamAccountName -UserPrincipalName $NewEmail
    # 2) Change mail attribute (alias for the 'mail' LDAP attribute)
    Set-ADUser -Identity $user.SamAccountName -EmailAddress $NewEmail  # uses -EmailAddress parameter :contentReference[oaicite:3]{index=3}

    # Success message
    Write-Host "✔  $OldEmail → $NewEmail" -ForegroundColor Green
    # Output for logging
    [PSCustomObject]@{
        SamAccountName = $user.SamAccountName
        OldEmail       = $OldEmail
        NewEmail       = $NewEmail
        Timestamp      = (Get-Date)
    }
}

#----- 1. Choose mode ----------------------------------------------------------
Write-Host "`n--- User Email/UPN Renamer ---`n"
$mode = Read-Host "Change a (S)ingle user or process a (C)SV file? [S/C]"
$result = @()

switch ($mode.ToUpper()) {

    'S' {
        $old = Read-Host "Enter CURRENT email (UPN)  e.g. geoffrey.traugott@boom.aero"
        $newPrefix = Read-Host "Enter NEW alias (everything before @boom.aero)  e.g. geoff.traugott"
        $new = "$newPrefix@boom.aero"
        $result += Rename-AdUserEmail -OldEmail $old -NewEmail $new
    }

    'C' {
        $path = Read-Host "Enter full path to CSV with columns OldEmail,NewEmail"
        if (-not (Test-Path $path)) { Write-Warning "File not found"; break }
        Import-Csv $path | ForEach-Object {
            $result += Rename-AdUserEmail -OldEmail $_.OldEmail -NewEmail $_.NewEmail
        }
    }

    default { Write-Host "No action selected."; return }
}

#----- 2. Optional Azure AD Connect delta sync ---------------------------------
$sync = Read-Host "`nTrigger Azure AD Connect delta sync now? [Y/N]"
if ($sync.ToUpper() -eq 'Y') {
    try {
        Start-ADSyncSyncCycle -PolicyType Delta   # needs to run on the AAD Connect server :contentReference[oaicite:4]{index=4}
        Write-Host "▲  Delta sync triggered."
    }
    catch { Write-Warning "Could not start sync: $_" }
}

#----- 3. Save a log -----------------------------------------------------------
if ($result) { $result | Export-Csv Rename-Log.csv -NoTypeInformation }
Write-Host "`nFinished. Log saved to Rename-Log.csv`n"
