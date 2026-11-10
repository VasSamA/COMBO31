---
lab:
    title: 'LAB02 - Criar o Domain Controller'
    module: 'Domingo 1 - Windows Server Core Infrastructure'
---

# LAB02 - Criar o Domain Controller

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB02 | AD DS, DNS | 75 min | 1 |

## O problema

Na CONTOSO, cada computador tem as suas próprias contas locais. Quando a Joana do Suporte muda de PC, perde o acesso a tudo. Quando um colaborador sai da empresa, ninguém sabe em quantos computadores ele tinha conta. Há palavras-passe escritas em post-its.

*"Quero uma única conta por pessoa, controlada num único sítio"*, disse o Director de TI.

## O que este lab resolve

A CONTOSO passa a ter uma **identidade central**: a floresta e o domínio **`corp.contoso.com`**, com o **CMB31-DC01** como Domain Controller e servidor DNS. A partir daqui, uma conta criada uma vez serve em qualquer computador da empresa. Esta identidade será, no Domingo 3, sincronizada para a cloud.

## Objectivos

- Instalar a role AD DS.
- Criar a floresta `corp.contoso.com` (NetBIOS `CONTOSO`).
- Validar o DNS integrado no AD (zonas, registos SRV, forwarders, zona inversa).
- Corrigir a configuração DNS de todos os servidores.
- Validar a saúde do DC com `dcdiag`.

## Pré-requisitos

- [LAB01](LAB_01_Preparar_Windows_Server.md) concluído.
- VMs a ligar: **CMB31-DC01, CMB31-SRV01, CMB31-ADM01**.

## Topologia

```text
CMB31-DC01 (10.31.10.10)
 ├── AD DS  : floresta + domínio corp.contoso.com (NetBIOS CONTOSO)
 └── DNS    : zona corp.contoso.com, _msdcs, zona inversa 10.31.10.x
               forwarders -> 1.1.1.1, 8.8.8.8
```

## Credenciais

| Conta | Palavra-passe |
|---|---|
| `Administrator` (antes) / `CONTOSO\Administrator` (depois) | `Pa55w.rd2027!` |
| DSRM (Directory Services Restore Mode) | `Pa55w.rd2027!` |

> **Porque é que o nome é `corp.contoso.com` e não `contoso.local`?** Um domínio AD deve ser um **subdomínio de um domínio público que a empresa controla**. Domínios `.local` dificultam a sincronização com o Microsoft 365 (LAB08) e podem colidir com mDNS. Em produção, a CONTOSO usaria um subdomínio do seu domínio real.

---

## Exercício 1: Instalar o AD DS e criar a floresta

### Tarefa 1: Instalar a role

1. No **CMB31-DC01**, abra o PowerShell como Administrador:

   ```powershell
   Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
   ```

1. Confirme `Success : True`.

### Tarefa 2: Promover a Domain Controller

1. Pode usar o assistente gráfico (**Server Manager > bandeira amarela > Promote this server to a domain controller**) ou o PowerShell. Use o PowerShell e leia cada parâmetro:

   ```powershell
   $dsrm = ConvertTo-SecureString 'Pa55w.rd2027!' -AsPlainText -Force
   Install-ADDSForest `
       -DomainName 'corp.contoso.com' `
       -DomainNetbiosName 'CONTOSO' `
       -InstallDns `
       -SafeModeAdministratorPassword $dsrm `
       -Force
   ```

   | Parâmetro | Significado |
   |---|---|
   | `-DomainName` | Nome DNS do domínio raiz da nova floresta |
   | `-DomainNetbiosName` | Nome curto (o que aparece em `CONTOSO\utilizador`) |
   | `-InstallDns` | Instala o DNS integrado no AD |
   | `-SafeModeAdministratorPassword` | Palavra-passe DSRM, usada para recuperar o AD |

1. Ignore os avisos sobre delegação DNS (é esperado: não existe zona pai `contoso.com` sob o nosso controlo). O servidor reinicia sozinho.
1. Inicie sessão como `CONTOSO\Administrator`. O primeiro arranque após a promoção é mais lento: é normal.

> **`Actualização 2026/2027`:** o Windows Server 2025 introduziu um novo nível funcional de floresta e domínio (**Windows Server 2025**), o primeiro desde o 2016. Um nível funcional mais alto desbloqueia funcionalidades novas, mas obriga todos os DCs a correrem essa versão. Na Tarefa 3 vai ver que nível ficou configurado (`DomainMode`). Em ambientes com DCs antigos, define-se `-ForestMode`/`-DomainMode` para o nível do DC mais antigo.

---

## Exercício 2: Validar o domínio e o DNS

### Tarefa 3: Verificar o domínio

1. No DC01:

   ```powershell
   Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode, PDCEmulator
   Get-ADForest | Select-Object Name, ForestMode, SchemaMaster
   Get-ADDomainController | Select-Object HostName, IPv4Address, IsGlobalCatalog
   ```

1. Abra **Active Directory Users and Computers** (`dsa.msc`). Observe os contentores por omissão: **Builtin, Computers, Domain Controllers, Users**. No LAB03 vai criar a sua própria estrutura de OUs.

### Tarefa 4: Verificar os registos SRV

Os clientes encontram o DC **através do DNS**, procurando registos SRV. Se estes registos não existirem, nada se junta ao domínio.

1. Execute:

   ```powershell
   Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.corp.contoso.com
   Resolve-DnsName -Type SRV _kerberos._tcp.corp.contoso.com
   ```

1. Ambos devem devolver `CMB31-DC01.corp.contoso.com` na porta 389 e 88.
1. Abra **DNS Manager** (`dnsmgmt.msc`) e explore **Forward Lookup Zones > corp.contoso.com > _tcp**.

### Tarefa 5: Configurar forwarders e zona inversa

1. Configure os forwarders e crie a zona inversa:

   ```powershell
   Set-DnsServerForwarder -IPAddress 1.1.1.1, 8.8.8.8
   Add-DnsServerPrimaryZone -NetworkId '10.31.10.0/24' -ReplicationScope Domain
   Add-DnsServerResourceRecordPtr -ZoneName '10.31.10.in-addr.arpa' -Name '10' -PtrDomainName 'CMB31-DC01.corp.contoso.com'
   ```

1. Teste a resolução externa **através do DC**:

   ```powershell
   Resolve-DnsName www.microsoft.com -Server 10.31.10.10
   Resolve-DnsName 10.31.10.10
   ```

### Tarefa 6: Corrigir o DNS de todos os servidores

Agora que o DNS interno existe, retire o DNS público temporário do LAB01. **Num domínio, os membros usam apenas DNS internos**; os pedidos externos saem pelos forwarders do DC.

1. No **DC01** (o DC aponta primeiro para si próprio pelo IP e depois para loopback):

   ```powershell
   $i = (Get-NetAdapter | Where-Object Status -eq 'Up').ifIndex
   Set-DnsClientServerAddress -InterfaceIndex $i -ServerAddresses 10.31.10.10, 127.0.0.1
   ```

1. No **ADM01**, em PowerShell como Administrador, corrija-se a si próprio e ao SRV01 (ainda em grupo de trabalho):

   ```powershell
   $i = (Get-NetAdapter | Where-Object Status -eq 'Up').ifIndex
   Set-DnsClientServerAddress -InterfaceIndex $i -ServerAddresses 10.31.10.10

   $cred = Get-Credential Administrator
   Invoke-Command -ComputerName 10.31.10.20 -Credential $cred -ScriptBlock {
       $i = (Get-NetAdapter | Where-Object Status -eq 'Up').ifIndex
       Set-DnsClientServerAddress -InterfaceIndex $i -ServerAddresses 10.31.10.10
       Resolve-DnsName corp.contoso.com
   }
   ```

1. Faça o mesmo na **CL01** quando a ligar no LAB03 (o lab lembra-o).

### Tarefa 7: Verificar a saúde do DC

1. No DC01:

   ```powershell
   dcdiag /q
   ```

   `/q` mostra **apenas erros**. Saída vazia = DC saudável. Avisos sobre o registo de eventos nos primeiros minutos são aceitáveis; volte a correr após 10 minutos.

1. Active já a **Lixeira do AD** (vai precisar dela no LAB06):

   ```powershell
   Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target 'corp.contoso.com' -Confirm:$false
   ```

---

## Evidência de conclusão

Guarde em `Evidencias\LAB02`:

1. Saída de `Get-ADDomain | Select DNSRoot, NetBIOSName, DomainMode`.
1. Saída do `Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.corp.contoso.com`.
1. Saída de `dcdiag /q` (vazia ou só avisos explicados).

## Validação

- [ ] Domínio `corp.contoso.com` com NetBIOS `CONTOSO`.
- [ ] Registos SRV `_ldap` e `_kerberos` resolvem para o DC01.
- [ ] Forwarders 1.1.1.1 e 8.8.8.8 configurados; resolução externa via DC funciona.
- [ ] Zona inversa `10.31.10.in-addr.arpa` com PTR do DC01.
- [ ] Nenhum servidor tem DNS público configurado.
- [ ] AD Recycle Bin activa.

## Troubleshooting

| Erro | Causa | Solução |
|---|---|---|
| `Install-ADDSForest`: *"The local Administrator account password does not meet requirements"* | Palavra-passe local em branco ou fraca | `net user Administrator Pa55w.rd2027!` e repita. |
| Registos SRV não existem | Serviço Netlogon não registou | `Restart-Service Netlogon` e `ipconfig /registerdns`; aguarde 2 minutos. |
| Sem Internet após remover o 1.1.1.1 | Forwarders não configurados | Tarefa 5. Teste com `Resolve-DnsName www.microsoft.com -Server 10.31.10.10`. |
| `dcdiag` mostra erro em **DFSREvent** ou **SystemLog** logo após a promoção | Eventos do arranque inicial | Aguarde 10 min e repita. Se persistir, consulte o **Event Viewer > DFS Replication**. |

## Challenge

Crie um registo DNS **CNAME** `intranet.corp.contoso.com` que aponte para `CMB31-SRV01.corp.contoso.com`, usando só PowerShell. Prove com `Resolve-DnsName`.

## Cleanup

Nada a limpar.

## Resultado esperado

A CONTOSO tem uma identidade central (`corp.contoso.com`) e um DNS interno saudável que resolve nomes internos e externos. Todos os servidores confiam no DC01 para DNS.

**Próximo lab:** [LAB03 - Estruturar a CONTOSO no AD](LAB_03_Estruturar_a_CONTOSO.md)
