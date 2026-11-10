<#
.SYNOPSIS
    COMBO PRO 3 em 1 - LAB03
    Cria a estrutura de OUs, grupos e os 50 utilizadores fictícios da CONTOSO.

.DESCRIPTION
    Executar no CMB31-DC01 (ou no CMB31-ADM01 com RSAT) como CONTOSO\Administrator.
    O script é idempotente: objectos que já existam são ignorados.

.EXAMPLE
    .\Import-ContosoUsers.ps1 -CsvPath .\contoso-users.csv
#>
[CmdletBinding()]
param(
    [string] $CsvPath = (Join-Path $PSScriptRoot 'contoso-users.csv'),
    [string] $DefaultPassword = 'Contoso#2027'
)

Import-Module ActiveDirectory -ErrorAction Stop
$domain   = Get-ADDomain
$domainDN = $domain.DistinguishedName
$upnSuffix = $domain.DNSRoot
$root     = "OU=_CONTOSO,$domainDN"
$depts    = 'TI','Financeiro','RH','Marketing','Vendas'

function New-OUIfMissing([string]$Name, [string]$Path) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        Write-Host "OU criada: $Name ($Path)" -ForegroundColor Cyan
    }
}

# --- OUs --------------------------------------------------------------------
New-OUIfMissing '_CONTOSO' $domainDN
'Utilizadores','Grupos','Computadores','Servidores','Admins' | ForEach-Object { New-OUIfMissing $_ $root }
$depts | ForEach-Object { New-OUIfMissing $_ "OU=Utilizadores,$root" }
New-OUIfMissing 'Postos' "OU=Computadores,$root"

# --- Grupos -----------------------------------------------------------------
$groupsOU = "OU=Grupos,$root"
$groups = @($depts | ForEach-Object { "GG_$_" }) + 'GG_Direccao','GG_Helpdesk','GG_Todos'
foreach ($g in $groups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $groupsOU `
                    -Description "CONTOSO - grupo $g"
        Write-Host "Grupo criado: $g" -ForegroundColor Cyan
    }
}

# --- Utilizadores -----------------------------------------------------------
$secure = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
$users  = Import-Csv -Path $CsvPath -Encoding UTF8
$created = 0
foreach ($u in $users) {
    $sam = $u.SamAccountName
    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) { continue }
    $ou = "OU=$($u.Department),OU=Utilizadores,$root"
    New-ADUser -Name "$($u.FirstName) $($u.LastName)" -GivenName $u.FirstName -Surname $u.LastName `
        -DisplayName "$($u.FirstName) $($u.LastName)" -SamAccountName $sam `
        -UserPrincipalName "$sam@$upnSuffix" -EmailAddress "$sam@$upnSuffix" `
        -Department $u.Department -Title $u.Title -Office $u.Office -Company $u.Company `
        -Path $ou -AccountPassword $secure -Enabled $true -ChangePasswordAtLogon $false
    Add-ADGroupMember -Identity "GG_$($u.Department)" -Members $sam
    Add-ADGroupMember -Identity 'GG_Todos' -Members $sam
    if ($u.Title -like 'Director*') { Add-ADGroupMember -Identity 'GG_Direccao' -Members $sam }
    $created++
}

# Equipa de suporte de TI no grupo Helpdesk
'edson.lukeny','joana.capita' | ForEach-Object {
    Add-ADGroupMember -Identity 'GG_Helpdesk' -Members $_ -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Utilizadores criados nesta execução: $created" -ForegroundColor Green
Get-ADUser -Filter * -SearchBase "OU=Utilizadores,$root" -Properties Department |
    Group-Object Department | Select-Object Name, Count | Format-Table
