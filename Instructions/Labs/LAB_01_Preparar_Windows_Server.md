---
lab:
    title: 'LAB01 - Preparar o Windows Server'
    module: 'Domingo 1 - Windows Server Core Infrastructure'
---

# LAB01 - Preparar o Windows Server

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB01 | Windows Server 2025, PowerShell, Windows Admin Center | 75 min | 1 |

## O problema

Os servidores da CONTOSO foram instalados "à pressa": têm nomes como `WIN-8F3KQ2L1`, recebem IPs aleatórios e o fuso horário está errado. Quando um servidor falha, ninguém sabe qual é nem onde está. Para administrar, o técnico tem de ir fisicamente à sala dos servidores.

O Director de TI, Paulo Kiala, foi claro: *"Antes de criarmos o domínio, quero cada servidor identificado, com IP fixo, à hora certa e gerível à distância."*

## O que este lab resolve

No fim deste lab, os servidores da CONTOSO têm **nomes padronizados, IPs fixos, DNS e fuso horário correctos**, e o administrador consegue geri-los **remotamente** a partir do servidor de administração (PowerShell Remoting e Windows Admin Center), incluindo o Server Core, que não tem interface gráfica.

## Objectivos

- Configurar nome, IP, DNS e fuso horário em Desktop Experience (GUI + PowerShell).
- Configurar um Server Core com `sconfig`.
- Usar PowerShell Remoting (`Enter-PSSession`, `Invoke-Command`).
- Instalar o Windows Admin Center e gerir os servidores a partir do browser.

## Pré-requisitos

- [LAB00](LAB_00_Preparar_o_Ambiente.md) concluído.
- VMs a ligar: **CMB31-DC01, CMB31-SRV01, CMB31-ADM01, CMB31-CL01**.

## Topologia

| VM antes | VM depois | IP | Gateway | DNS |
|---|---|---|---|---|
| CMB31-DC01 | `CMB31-DC01` | 10.31.10.10/24 | 10.31.10.1 | 10.31.10.10, 1.1.1.1 (temporário) |
| CMB31-SRV01 | `CMB31-SRV01` | 10.31.10.20/24 | 10.31.10.1 | 10.31.10.10, 1.1.1.1 (temporário) |
| CMB31-ADM01 | `CMB31-ADM01` | 10.31.10.30/24 | 10.31.10.1 | 10.31.10.10, 1.1.1.1 (temporário) |
| CMB31-CL01 | `CMB31-CL01` | 10.31.10.101/24 | 10.31.10.1 | 10.31.10.10, 1.1.1.1 (temporário) |

> **Porquê 1.1.1.1 como DNS secundário?** O DNS interno (DC01) ainda não existe. Usamos um DNS público **só até ao LAB02** para descarregar o Windows Admin Center. No LAB02 removemos este DNS: num domínio, os membros devem usar **apenas** DNS internos.

## Credenciais

`Administrator` / `Pa55w.rd2027!` (servidores) e `labadmin` / `Pa55w.rd2027!` (CL01).

---

## Exercício 1: Configurar o CMB31-DC01 (Desktop Experience)

### Tarefa 1: Configurar pela interface gráfica

1. Inicie sessão no **CMB31-DC01** como `Administrator`.
1. No **Server Manager**, seleccione **Local Server**.
1. Seleccione o nome do computador (`WIN-...`) > **Change** > nome `CMB31-DC01` > **OK**. **Não reinicie ainda.**
1. Seleccione o adaptador **Ethernet** > botão direito > **Properties** > **Internet Protocol Version 4 (TCP/IPv4)** > **Properties** e configure:
   - IP: `10.31.10.10`, máscara: `255.255.255.0`, gateway: `10.31.10.1`
   - DNS preferido: `10.31.10.10`, alternativo: `1.1.1.1`
1. Em **Time zone**, escolha **(UTC+01:00) West Central Africa**.
1. Reinicie o servidor.

### Tarefa 2: Confirmar com PowerShell

1. Abra o **PowerShell** como Administrador e execute:

   ```powershell
   hostname
   Get-NetIPConfiguration
   Get-TimeZone | Select-Object Id
   Test-NetConnection -ComputerName www.microsoft.com -Port 443
   ```

1. Confirme `TcpTestSucceeded : True`. Se falhar, veja o Troubleshooting.

---

## Exercício 2: Configurar o CMB31-SRV01 (Server Core)

### Tarefa 3: Configurar com sconfig

1. Inicie sessão no **CMB31-SRV01** como `Administrator`. Aparece a consola de texto do **SConfig**.
1. Opção **8) Network settings** > seleccione o índice do adaptador > **1) Set network adapter address** > **S (Static)**:
   - IP `10.31.10.20`, máscara `255.255.255.0`, gateway `10.31.10.1`.
1. Na mesma área, **2) Set DNS servers**: `10.31.10.10` e `1.1.1.1`. Volte ao menu principal.
1. Opção **9) Date and time** > fuso horário **(UTC+01:00) West Central Africa**.
1. Opção **7) Remote desktop**: deixe **desactivado** (Server Core gere-se remotamente).
1. Opção **2) Computer name** > `CMB31-SRV01` > aceite reiniciar.

### Tarefa 4: Confirmar sem interface gráfica

1. Após reiniciar, escolha **15) Exit to command line (PowerShell)**.
1. Execute:

   ```powershell
   hostname
   Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, IPAddress
   Get-Service WinRM
   ```

   O serviço **WinRM** deve estar `Running`. É ele que permite a gestão remota.

> Para voltar ao menu, escreva `sconfig`.

---

## Exercício 3: Configurar ADM01 e CL01 só com PowerShell

### Tarefa 5: CMB31-ADM01

1. Inicie sessão no **CMB31-ADM01** e abra o PowerShell como Administrador:

   ```powershell
   $nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
   New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 10.31.10.30 -PrefixLength 24 -DefaultGateway 10.31.10.1
   Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses 10.31.10.10, 1.1.1.1
   Set-TimeZone -Id 'W. Central Africa Standard Time'
   Rename-Computer -NewName 'CMB31-ADM01' -Restart
   ```

### Tarefa 6: CMB31-CL01

1. Inicie sessão no **CMB31-CL01** como `labadmin` e abra o **Terminal (Administrador)**.
1. Execute os mesmos comandos, com o IP `10.31.10.101` e o nome `CMB31-CL01`.

---

## Exercício 4: Gestão remota

### Tarefa 7: PowerShell Remoting em grupo de trabalho

Os servidores ainda **não estão num domínio**. O PowerShell Remoting entre máquinas de grupo de trabalho exige que o cliente confie explicitamente nos destinos (TrustedHosts).

1. No **CMB31-ADM01**, PowerShell como Administrador:

   ```powershell
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value '10.31.10.*,CMB31-*' -Force
   $cred = Get-Credential -UserName 'Administrator' -Message 'Pa55w.rd2027!'
   Enter-PSSession -ComputerName 10.31.10.20 -Credential $cred
   ```

1. O prompt muda para `[10.31.10.20]: PS>`. Está **dentro do Server Core**. Execute:

   ```powershell
   hostname
   Get-WindowsFeature | Where-Object Installed | Select-Object -First 10 Name
   Exit-PSSession
   ```

1. Agora execute o mesmo comando em **dois servidores ao mesmo tempo**:

   ```powershell
   Invoke-Command -ComputerName 10.31.10.10, 10.31.10.20 -Credential $cred -ScriptBlock {
       [pscustomobject]@{ Servidor = $env:COMPUTERNAME; Uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime }
   }
   ```

> **Ponto de atenção:** `TrustedHosts` com caracteres universais é aceitável em laboratório. Em produção, a gestão remota faz-se dentro do domínio com Kerberos (LAB03 em diante).

### Tarefa 8: Instalar o Windows Admin Center

1. No **CMB31-ADM01**, abra o Edge e aceda a `https://aka.ms/WACDownload`. Guarde o instalador.
1. Execute o instalador e aceite as opções por omissão (porta **443**, certificado auto-assinado).
1. Abra `https://cmb31-adm01` no Edge. Aceite o aviso do certificado auto-assinado.
1. Seleccione **+ Add > Servers > Add**, escreva `10.31.10.20` e, em **Credentials**, use `Administrator` / `Pa55w.rd2027!`.
1. Repita para `10.31.10.10`.
1. Abra o **CMB31-SRV01** no WAC e explore: **Overview**, **Services**, **Firewall**, **PowerShell**.
1. Em **Services**, procure o serviço **Print Spooler**: num File Server não é necessário. **Pare-o e defina-o como Disabled** a partir do WAC.

> **`Actualização 2026/2027`:** o Windows Admin Center actual (geração "modernized gateway") substituiu a versão 1910 usada em materiais antigos. A experiência é a mesma, mas o instalador e os requisitos mudaram.

### Tarefa 9: Checkpoint

1. No portátil:

   ```powershell
   Get-VM -Name 'CMB31-DC01','CMB31-SRV01','CMB31-ADM01','CMB31-CL01' | Checkpoint-VM -SnapshotName '01-Configurado'
   ```

---

## Evidência de conclusão

Guarde em `Evidencias\LAB01`:

1. Captura do Windows Admin Center com **CMB31-DC01** e **CMB31-SRV01** na lista de ligações.
1. Saída do `Invoke-Command` da Tarefa 7.

## Validação

- [ ] Os 4 computadores têm o nome `CMB31-*` correcto.
- [ ] Todos têm IP fixo na rede 10.31.10.0/24 e chegam à Internet.
- [ ] Fuso horário **W. Central Africa Standard Time** em todos.
- [ ] `Enter-PSSession` ao SRV01 funciona a partir do ADM01.
- [ ] WAC instalado no ADM01 e a gerir DC01 e SRV01.
- [ ] Serviço Print Spooler desactivado no SRV01.

## Troubleshooting

| Erro | Causa | Solução |
|---|---|---|
| `Test-NetConnection` falha para a Internet | Gateway errado ou NAT em falta | Gateway tem de ser `10.31.10.1`. No portátil: `Get-NetNat`. |
| `Enter-PSSession`: *"The WinRM client cannot process the request... TrustedHosts"* | TrustedHosts não configurado no ADM01 | Repita o `Set-Item WSMan:\...TrustedHosts`. |
| `Enter-PSSession`: *"Access is denied"* | Credencial errada | Use `Administrator` (não `labadmin`) e a palavra-passe do servidor. |
| Ping entre VMs não responde | Firewall do Windows bloqueia ICMP por omissão | Normal. Use `Test-NetConnection -Port 5985` para testar WinRM. |
| WAC não abre | Serviço não arrancou | `Get-Service WindowsAdminCenter*` e `Start-Service`. |

## Challenge

Sem usar o `sconfig`, **altere o fuso horário do SRV01 a partir do ADM01** com um único comando `Invoke-Command`, e prove que mudou.

## Cleanup

Nada a limpar. Pode desligar a CL01 até ao LAB03.

## Resultado esperado

Quatro máquinas identificadas, endereçadas e geridas centralmente a partir do CMB31-ADM01. A CONTOSO tem agora a base para o domínio.

**Próximo lab:** [LAB02 - Criar o Domain Controller](LAB_02_Criar_Domain_Controller.md)
