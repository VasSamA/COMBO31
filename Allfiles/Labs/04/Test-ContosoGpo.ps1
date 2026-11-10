<#
.SYNOPSIS
    COMBO PRO 3 em 1 - LAB04
    Verifica, num posto de trabalho, se as GPOs da CONTOSO estão aplicadas.

.DESCRIPTION
    Executar na CMB31-CL01, com sessão iniciada por um utilizador do domínio
    (por exemplo CONTOSO\patricia.lunda). Não precisa de privilégios de administrador.
#>

$results = @()

function Add-Check($Name, [bool]$Ok, $Detail) {
    $script:results += [pscustomobject]@{ Verificacao = $Name; Estado = if ($Ok) { 'OK' } else { 'FALHA' }; Detalhe = $Detail }
}

# 1. Bloqueio por inactividade (política de computador)
$inactivity = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue).InactivityTimeoutSecs
Add-Check 'Bloqueio por inactividade = 600 s' ($inactivity -eq 600) "Valor: $inactivity"

# 2. Aviso legal no início de sessão
$caption = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue).legalnoticecaption
Add-Check 'Aviso legal configurado' (-not [string]::IsNullOrWhiteSpace($caption)) "Título: $caption"

# 3. Painel de Controlo bloqueado (só para Marketing)
$noCpl = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -ErrorAction SilentlyContinue).NoControlPanel
$isMkt = (whoami /groups) -match 'GG_Marketing'
if ($isMkt) {
    Add-Check 'Painel de Controlo bloqueado (Marketing)' ($noCpl -eq 1) "NoControlPanel: $noCpl"
} else {
    Add-Check 'Painel de Controlo livre (não-Marketing)' ($noCpl -ne 1) "NoControlPanel: $noCpl"
}

# 4. Windows LAPS
$laps = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Policies\LAPS' -ErrorAction SilentlyContinue
Add-Check 'Windows LAPS configurado por GPO' ($null -ne $laps) "BackupDirectory: $($laps.BackupDirectory)"

$results | Format-Table -AutoSize
Write-Host ''
Write-Host 'GPOs aplicadas ao computador e ao utilizador:' -ForegroundColor Cyan
gpresult /r /scope:computer | Select-String 'GPO-CONTOSO'
gpresult /r /scope:user | Select-String 'GPO-CONTOSO'
