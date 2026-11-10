<#
.SYNOPSIS
    COMBO PRO 3 em 1 - LAB00
    Cria a rede e as 5 VMs do laboratório CONTOSO em Hyper-V.

.DESCRIPTION
    - Cria o virtual switch interno CMB31-LAN
    - Atribui 10.31.10.1/24 ao adaptador do host e cria o NAT CMB31-NAT
    - Cria as VMs CMB31-DC01, CMB31-SRV01, CMB31-ADM01, CMB31-CL01, CMB31-CL02
      (Geração 2, Secure Boot, memória dinâmica, vTPM nos clientes)
    - Liga a ISO correcta a cada VM e define o arranque pelo DVD

    Executar no portátil (host), em PowerShell como Administrador.
    O script é idempotente: o que já existir é ignorado.

.EXAMPLE
    .\New-CMB31Lab.ps1 -ServerIso 'D:\ISO\WS2025.iso' -ClientIso 'D:\ISO\Win11Ent.iso' -VmPath 'D:\Hyper-V\CMB31'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ServerIso,
    [Parameter(Mandatory)] [string] $ClientIso,
    [string] $VmPath = 'C:\Hyper-V\CMB31',
    [switch] $SkipClients
)

$ErrorActionPreference = 'Stop'

# --- Verificações -----------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Execute este script numa consola PowerShell como Administrador.'
}
if (-not (Get-Command New-VM -ErrorAction SilentlyContinue)) {
    throw 'Hyper-V não está instalado. Ver LAB00, Tarefa 1.'
}
foreach ($iso in @($ServerIso, $ClientIso)) {
    if (-not (Test-Path $iso)) { throw "ISO não encontrada: $iso" }
}
New-Item -ItemType Directory -Path $VmPath -Force | Out-Null

# --- Rede -------------------------------------------------------------------
$switchName = 'CMB31-LAN'
if (-not (Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue)) {
    Write-Host "A criar virtual switch $switchName..." -ForegroundColor Cyan
    New-VMSwitch -Name $switchName -SwitchType Internal | Out-Null
}
$hostNic = Get-NetAdapter | Where-Object Name -eq "vEthernet ($switchName)"
if (-not (Get-NetIPAddress -InterfaceIndex $hostNic.ifIndex -IPAddress 10.31.10.1 -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -InterfaceIndex $hostNic.ifIndex -IPAddress 10.31.10.1 -PrefixLength 24 | Out-Null
}
if (-not (Get-NetNat -Name 'CMB31-NAT' -ErrorAction SilentlyContinue)) {
    Write-Host 'A criar NAT CMB31-NAT (10.31.10.0/24)...' -ForegroundColor Cyan
    New-NetNat -Name 'CMB31-NAT' -InternalIPInterfaceAddressPrefix '10.31.10.0/24' | Out-Null
}

# --- Definição das VMs ------------------------------------------------------
$vms = @(
    @{ Name = 'CMB31-DC01';  Iso = $ServerIso; Min = 1GB;   Start = 2GB; Max = 4GB; Disk = 60GB; Client = $false },
    @{ Name = 'CMB31-SRV01'; Iso = $ServerIso; Min = 512MB; Start = 1GB; Max = 2GB; Disk = 60GB; Client = $false },
    @{ Name = 'CMB31-ADM01'; Iso = $ServerIso; Min = 1GB;   Start = 2GB; Max = 4GB; Disk = 60GB; Client = $false }
)
if (-not $SkipClients) {
    $vms += @{ Name = 'CMB31-CL01'; Iso = $ClientIso; Min = 2GB; Start = 4GB; Max = 4GB; Disk = 80GB; Client = $true }
    $vms += @{ Name = 'CMB31-CL02'; Iso = $ClientIso; Min = 2GB; Start = 4GB; Max = 4GB; Disk = 80GB; Client = $true }
}

foreach ($v in $vms) {
    if (Get-VM -Name $v.Name -ErrorAction SilentlyContinue) {
        Write-Host "$($v.Name) já existe - ignorado." -ForegroundColor Yellow
        continue
    }
    Write-Host "A criar $($v.Name)..." -ForegroundColor Cyan
    $vhd = Join-Path $VmPath "$($v.Name)\$($v.Name).vhdx"
    New-VM -Name $v.Name -Generation 2 -MemoryStartupBytes $v.Start -NewVHDPath $vhd `
           -NewVHDSizeBytes $v.Disk -SwitchName $switchName -Path $VmPath | Out-Null
    Set-VMProcessor -VMName $v.Name -Count 2
    Set-VMMemory -VMName $v.Name -DynamicMemoryEnabled $true `
                 -MinimumBytes $v.Min -StartupBytes $v.Start -MaximumBytes $v.Max
    Set-VM -Name $v.Name -AutomaticCheckpointsEnabled $false -CheckpointType Standard
    Add-VMDvdDrive -VMName $v.Name -Path $v.Iso
    $dvd = Get-VMDvdDrive -VMName $v.Name
    Set-VMFirmware -VMName $v.Name -FirstBootDevice $dvd -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows
    Enable-VMIntegrationService -VMName $v.Name -Name 'Guest Service Interface'
    if ($v.Client) {
        # Windows 11 exige TPM 2.0
        Set-VMKeyProtector -VMName $v.Name -NewLocalKeyProtector
        Enable-VMTPM -VMName $v.Name
    }
}

Write-Host ''
Write-Host 'Concluído. Próximo passo: LAB00, Tarefa 4 - instalar o sistema operativo em cada VM.' -ForegroundColor Green
Get-VM -Name 'CMB31-*' | Select-Object Name, State, @{n='RAM(GB)';e={$_.MemoryStartup/1GB}} | Format-Table
