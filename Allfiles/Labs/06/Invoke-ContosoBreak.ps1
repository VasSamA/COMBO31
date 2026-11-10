<#
.SYNOPSIS
    COMBO PRO 3 em 1 - LAB06 - Cenários de avaria (break/fix)

.DESCRIPTION
    NÃO LEIA ESTE SCRIPT ANTES DE RESOLVER OS CENÁRIOS. O objectivo é diagnosticar
    a partir dos sintomas, como faria num pedido real de suporte.

    Executar no CMB31-ADM01 como CONTOSO\Administrator.
      .\Invoke-ContosoBreak.ps1 -Scenario 1      # introduz a avaria 1
      .\Invoke-ContosoBreak.ps1 -Scenario 1 -Reset   # repõe o estado correcto (só se desistir)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet(1,2,3,4)] [int] $Scenario,
    [switch] $Reset
)
$ErrorActionPreference = 'Stop'

switch ($Scenario) {
    1 {
        if ($Reset) {
            Invoke-Command -ComputerName CMB31-CL01 -ScriptBlock {
                $i = (Get-NetAdapter | Where-Object Status -eq 'Up').ifIndex
                Set-DnsClientServerAddress -InterfaceIndex $i -ResetServerAddresses
                ipconfig /flushdns | Out-Null
            }
        } else {
            Invoke-Command -ComputerName CMB31-CL01 -ScriptBlock {
                $i = (Get-NetAdapter | Where-Object Status -eq 'Up').ifIndex
                Set-DnsClientServerAddress -InterfaceIndex $i -ServerAddresses 8.8.8.8
                ipconfig /flushdns | Out-Null
            }
        }
    }
    2 {
        if ($Reset) { Add-ADGroupMember -Identity GG_Marketing -Members patricia.lunda }
        else        { Remove-ADGroupMember -Identity GG_Marketing -Members patricia.lunda -Confirm:$false }
    }
    3 {
        $dns = if ($Reset) { '10.31.10.10' } else { '10.31.10.99' }
        Set-DhcpServerv4OptionValue -ComputerName CMB31-DC01 -ScopeId 10.31.10.0 -DnsServer $dns -Force
    }
    4 {
        if ($Reset) {
            Invoke-Command -ComputerName CMB31-SRV01 -ScriptBlock {
                Set-Service LanmanServer -StartupType Automatic; Start-Service LanmanServer
            }
        } else {
            Invoke-Command -ComputerName CMB31-SRV01 -ScriptBlock {
                Stop-Service LanmanServer -Force; Set-Service LanmanServer -StartupType Disabled
            }
        }
    }
}
if ($Reset) { Write-Host "Cenário $Scenario reposto." -ForegroundColor Green }
else        { Write-Host "Cenário $Scenario activo. Leia os sintomas no LAB06 e comece o diagnóstico." -ForegroundColor Yellow }
