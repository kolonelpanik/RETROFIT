<#
.SYNOPSIS
    Safely rename on‑prem AD users (UPN + mail) with a dry‑run default.
.DESCRIPTION
    • Preview mode (default): shows exactly what will change.
    • Commit mode        : supply -DoIt (alias -Commit) to enact changes.
    • Accepts single‑user interactive input OR a CSV (OldEmail,NewEmail).
    • Triggers Azure AD Connect delta sync only when -DoIt is present.
.NOTES
    Requires RSAT ActiveDirectory module and (optionally) ADSync module.
#>

function Invoke‑RetrofitRename {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Alias('Commit')]
        [switch]$DoIt,

        [string]$CsvPath
    )

    Import-Module ActiveDirectory -ErrorAction Stop   # ensures Set‑ADUser

    #--- helper ---------------------------------------------------------------
    function Rename‑One {
        param($OldEmail,$NewEmail)
        $user = Get-ADUser -Filter "UserPrincipalName -eq '$OldEmail'" `
                 -Properties SamAccountName,UserPrincipalName,Mail
        if(!$user){Write-Warning "✖  $OldEmail not found";return}

        $action = "rename $($user.UserPrincipalName) → $NewEmail"
        if($PSCmdlet.ShouldProcess($action)){
            # When -DoIt is absent we force -WhatIf
            $wi = !$DoIt
            Set-ADUser $user -UserPrincipalName $NewEmail -WhatIf:$wi
            Set-ADUser $user -EmailAddress    $NewEmail -WhatIf:$wi
            Write-Host ("{0} {1}" -f ($DoIt?'✔':'WHATIF:'),$action)
        }
    }

    #--- gather targets -------------------------------------------------------
    if($CsvPath){
        Import-Csv $CsvPath | ForEach-Object {
            Rename‑One $_.OldEmail $_.NewEmail
        }
    }
    else{
        $old = Read-Host 'Current email/UPN  (e.g. geoffrey.traugott@boom.aero)'
        $newLocal = Read-Host 'New alias before @boom.aero (e.g. geoff.traugott)'
        Rename‑One $old "$newLocal@boom.aero"
    }

    #--- optional sync --------------------------------------------------------
    if($DoIt){
        if(Get-Command Start-ADSyncSyncCycle -ErrorAction SilentlyContinue){
            Start-ADSyncSyncCycle -PolicyType Delta   # export to Entra ID
        }
        else{Write-Warning 'ADSync cmdlets not available on this server.'}
    }
    elseif($PSCmdlet.ShouldProcess('Azure AD Connect','Preview delta sync')){
        Write-Host 'WHATIF: would run Start‑ADSyncSyncCycle -PolicyType Delta'
    }
}
