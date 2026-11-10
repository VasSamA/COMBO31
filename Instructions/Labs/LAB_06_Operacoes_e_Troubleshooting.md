---
lab:
    title: 'LAB06 - Operações e troubleshooting'
    module: 'Domingo 2 - Windows Server Administration & Security'
---

# LAB06 - Operações e troubleshooting

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB06 | DHCP, AD Recycle Bin, Windows Server Backup, metodologia de troubleshooting | 105 min | 2 |

## O problema

Segunda-feira de manhã, o Suporte da CONTOSO recebe quatro chamadas:

1. *"Apagaram por engano a conta do Tiago do Marketing. Ele não consegue entrar."*
1. *"Cada vez que ligamos um portátil novo, alguém tem de configurar o IP à mão."*
1. *"Se o servidor de ficheiros arder, perdemos tudo?"*
1. *"Não consigo entrar / não vejo a minha unidade / a rede não funciona."*

O Director de TI quer que a equipa saiba **recuperar** e **diagnosticar** de forma metódica, e não por tentativa e erro.

## O que este lab resolve

A CONTOSO fica com **endereçamento automático (DHCP)**, sabe **recuperar objectos apagados do AD** em segundos, tem **cópias de segurança do File Server testadas com restauro**, e a equipa pratica uma **metodologia de troubleshooting** em quatro avarias reais.

## Objectivos

- Instalar, autorizar e configurar um servidor DHCP.
- Restaurar um utilizador apagado com a AD Recycle Bin.
- Fazer e **restaurar** um backup com Windows Server Backup.
- Diagnosticar avarias de DNS, grupos, DHCP e serviços.

## Pré-requisitos

- [LAB05](LAB_05_File_Server_e_Permissoes.md) concluído. AD Recycle Bin activada no [LAB02](LAB_02_Criar_Domain_Controller.md).
- VMs a ligar: **CMB31-DC01, CMB31-SRV01, CMB31-ADM01, CMB31-CL01**.
- Script: `Allfiles/Labs/06/Invoke-ContosoBreak.ps1` (copiar para `C:\Labfiles\06` no ADM01).

## Topologia

| Serviço | Onde | Configuração |
|---|---|---|
| DHCP | CMB31-DC01 | Âmbito `10.31.10.100-150`, gateway `.1`, DNS `.10`, domínio `corp.contoso.com` |
| Backup | CMB31-SRV01 > `\\CMB31-ADM01\Backup$` | Pasta `E:\Shares` |

## Credenciais

`CONTOSO\Administrator` / `Pa55w.rd2027!`. Utilizadores de teste / `Contoso#2027`.

---

## Exercício 1: DHCP

### Tarefa 1: Instalar e autorizar

1. No **ADM01** (as ferramentas DHCP foram instaladas no LAB03):

   ```powershell
   Install-WindowsFeature -ComputerName CMB31-DC01 -Name DHCP -IncludeManagementTools
   Add-DhcpServerInDC -DnsName CMB31-DC01.corp.contoso.com -IPAddress 10.31.10.10
   Get-DhcpServerInDC
   ```

> **Porquê autorizar?** Num domínio, um servidor DHCP Windows só distribui endereços se estiver **autorizado no AD**. Isto impede que um servidor DHCP "pirata" ligado à rede comece a distribuir configurações erradas.

1. Elimine o aviso do Server Manager criando os grupos de segurança do DHCP:

   ```powershell
   Invoke-Command -ComputerName CMB31-DC01 -ScriptBlock { netsh dhcp add securitygroups; Restart-Service DHCPServer }
   ```

### Tarefa 2: Criar o âmbito

1. No ADM01:

   ```powershell
   Add-DhcpServerv4Scope -ComputerName CMB31-DC01 -Name 'CONTOSO-Postos' `
       -StartRange 10.31.10.100 -EndRange 10.31.10.150 -SubnetMask 255.255.255.0 -LeaseDuration 8.00:00:00
   Set-DhcpServerv4OptionValue -ComputerName CMB31-DC01 -ScopeId 10.31.10.0 `
       -Router 10.31.10.1 -DnsServer 10.31.10.10 -DnsDomain corp.contoso.com
   Get-DhcpServerv4Scope -ComputerName CMB31-DC01
   ```

### Tarefa 3: Passar a CL01 para DHCP

1. Na **CL01**, Terminal como administrador (`CONTOSO\Administrator`):

   ```powershell
   $i = (Get-NetAdapter | Where-Object Status -eq 'Up').ifIndex
   Remove-NetIPAddress -InterfaceIndex $i -AddressFamily IPv4 -Confirm:$false
   Remove-NetRoute -InterfaceIndex $i -DestinationPrefix 0.0.0.0/0 -Confirm:$false
   Set-NetIPInterface -InterfaceIndex $i -Dhcp Enabled
   Set-DnsClientServerAddress -InterfaceIndex $i -ResetServerAddresses
   ipconfig /renew
   ipconfig /all
   Enable-PSRemoting -Force    # o Windows 11 não aceita gestão remota por omissão; necessário no Exercício 4
   ```

1. Confirme: IP entre `.100` e `.150`, **DHCP Enabled: Yes**, DNS `10.31.10.10`.
1. No ADM01: `Get-DhcpServerv4Lease -ComputerName CMB31-DC01 -ScopeId 10.31.10.0`.

---

## Exercício 2: "Apagaram o Tiago"

### Tarefa 4: Apagar (de propósito)

1. No ADM01:

   ```powershell
   Get-ADUser tiago.muxima -Properties MemberOf | Select-Object Name, MemberOf
   Remove-ADUser tiago.muxima -Confirm:$false
   ```

### Tarefa 5: Restaurar com a AD Recycle Bin

1. Encontre o objecto apagado:

   ```powershell
   Get-ADObject -Filter "SamAccountName -eq 'tiago.muxima'" -IncludeDeletedObjects -Properties LastKnownParent
   ```

1. Restaure:

   ```powershell
   Get-ADObject -Filter "SamAccountName -eq 'tiago.muxima'" -IncludeDeletedObjects | Restore-ADObject
   Get-ADUser tiago.muxima -Properties MemberOf | Select-Object Name, DistinguishedName, MemberOf
   ```

1. Repare: o utilizador voltou **para a mesma OU, com os mesmos grupos e a mesma palavra-passe**. Sem a Recycle Bin, teria de usar um restauro autoritativo a partir de backup.

> Também pode restaurar visualmente: **Active Directory Administrative Center > corp (local) > Deleted Objects > botão direito > Restore**.

---

## Exercício 3: Backup e restauro do File Server

### Tarefa 6: Preparar o destino

1. No **ADM01**, crie uma partilha oculta para receber backups:

   ```powershell
   New-Item -ItemType Directory C:\Backup -Force
   New-SmbShare -Name 'Backup$' -Path C:\Backup -FullAccess 'CONTOSO\Domain Admins','CONTOSO\CMB31-SRV01$'
   icacls C:\Backup /grant 'CONTOSO\CMB31-SRV01$:(OI)(CI)M'
   ```

> Em produção o destino de backup **nunca** fica no mesmo edifício. No LAB17 a CONTOSO resolve isto com o Azure Backup.

### Tarefa 7: Fazer o backup

1. No ADM01:

   ```powershell
   Invoke-Command -ComputerName CMB31-SRV01 -ScriptBlock {
       Install-WindowsFeature Windows-Server-Backup
   }
   Enter-PSSession CMB31-SRV01
   wbadmin start backup -backupTarget:\\CMB31-ADM01\Backup$ -include:E:\Shares -quiet
   wbadmin get versions -backupTarget:\\CMB31-ADM01\Backup$
   ```

   Anote o **Version identifier** (ex.: `11/08/2027-10:15`).

> Usamos `Enter-PSSession` porque o `wbadmin` precisa de aceder à partilha de rede com as credenciais da sessão; dentro de `Invoke-Command` isso causaria o problema de "double hop".

### Tarefa 8: Desastre e restauro

1. Ainda na sessão remota ao SRV01, simule a perda da pasta RH:

   ```powershell
   Remove-Item E:\Shares\RH\* -Recurse -Force
   New-Item E:\Restauro -ItemType Directory
   wbadmin start recovery -version:<Version identifier> -itemType:File -items:E:\Shares\RH `
       -backupTarget:\\CMB31-ADM01\Backup$ -recoveryTarget:E:\Restauro -recursive -quiet
   Get-ChildItem E:\Restauro -Recurse
   Exit-PSSession
   ```

1. Copie os ficheiros restaurados de volta para `E:\Shares\RH`. Um backup só vale alguma coisa **depois de um restauro testado**.

---

## Exercício 4: Troubleshooting metódico

### A metodologia

1. **Recolher sintomas:** quem, o quê, desde quando, o que mudou.
1. **Isolar a camada:** rede (IP/gateway) > nome (DNS) > autenticação (AD/grupos) > serviço (SMB/GPO).
1. **Testar uma hipótese de cada vez**, com comandos, não com palpites.
1. **Corrigir, validar e documentar.**

**Ferramentas:** `ipconfig /all`, `Test-NetConnection`, `Resolve-DnsName`/`nslookup`, `whoami /groups`, `gpresult /r`, `Get-Service`, `Get-SmbShare`, **Event Viewer**.

### Tarefa 9: Resolver as quatro avarias

Para cada cenário: no ADM01 execute `.\Invoke-ContosoBreak.ps1 -Scenario N`, leia o sintoma, **diagnostique e corrija sem ler o script**. Registe na tabela abaixo.

| # | Sintoma reportado |
|---|---|
| 1 | *"Na CL01, o gpupdate dá erro e o \\\\CMB31-SRV01 não abre, mas a Internet funciona."* |
| 2 | *"Sou a Patrícia do Marketing. Desde hoje não vejo a unidade M: e não consigo abrir a pasta Marketing."* (termine sessão e volte a entrar na CL01 como `patricia.lunda` depois de activar o cenário) |
| 3 | *"Os portáteis novos ligam-se à rede mas não conseguem entrar no domínio."* (na CL01: `ipconfig /release` e `ipconfig /renew` depois de activar o cenário) |
| 4 | *"Ninguém consegue abrir nenhuma pasta partilhada. O servidor responde ao ping."* |

Modelo de registo (copie para a sua evidência):

| # | Hipóteses testadas | Comando que revelou a causa | Causa | Correcção |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |

> Só use `-Reset` se ficar bloqueado(a) mais de 20 minutos num cenário. Depois de repor, leia o script para perceber o que mudou.

### Tarefa 10: Checkpoint de fim do Windows Server

```powershell
# No portátil
Get-VM -Name 'CMB31-*' | Where-Object Name -ne 'CMB31-CL02' | Checkpoint-VM -SnapshotName '06-Fim-Windows-Server'
```

---

## Evidência de conclusão

Guarde em `Evidencias\LAB06`:

1. `ipconfig /all` da CL01 com DHCP.
1. Saída do `Restore-ADObject` e do `Get-ADUser tiago.muxima`.
1. Saída do `wbadmin start recovery` e da listagem de `E:\Restauro`.
1. Tabela de troubleshooting preenchida com os 4 cenários.

## Validação

- [ ] DHCP autorizado e CL01 com endereço do âmbito.
- [ ] Utilizador apagado restaurado com grupos intactos.
- [ ] Backup do `E:\Shares` feito **e** restauro testado.
- [ ] 4 avarias diagnosticadas com causa e correcção documentadas.

## Troubleshooting

| Sintoma | Solução |
|---|---|
| CL01 recebe IP `169.254.x.x` | DHCP não autorizado ou âmbito inactivo: `Get-DhcpServerv4Scope -ComputerName CMB31-DC01` (State = Active). |
| `Restore-ADObject`: objecto não encontrado | Recycle Bin não estava activa antes da eliminação. Confirme: `Get-ADOptionalFeature 'Recycle Bin Feature'`. |
| `wbadmin`: *"Access is denied"* para a partilha | A conta de computador `CMB31-SRV01$` não tem permissão NTFS/partilha. Repita a Tarefa 6. |
| `wbadmin` não existe | Feature `Windows-Server-Backup` não instalada. |

## Challenge

1. Crie uma **reserva DHCP** para que a CL01 receba sempre `10.31.10.120`, usando o endereço MAC dela.
1. Crie uma **tarefa agendada** no SRV01 que faça o backup do `E:\Shares` todos os dias às 20h00.

## Cleanup

Confirme que **os 4 cenários estão corrigidos** (ou use `-Reset` em todos). O ambiente tem de estar saudável para o Domingo 3.

## Resultado esperado

A CONTOSO tem endereçamento automático, recupera objectos e ficheiros, e a equipa resolve avarias com método. **Fim do Windows Server.** No Domingo 3, esta identidade local é levada para a cloud.

**Próximo lab:** [LAB07 - Tenant Microsoft 365](LAB_07_Tenant_e_Dominio.md)
