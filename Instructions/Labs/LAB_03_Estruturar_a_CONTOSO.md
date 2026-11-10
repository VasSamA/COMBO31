---
lab:
    title: 'LAB03 - Estruturar a CONTOSO no Active Directory'
    module: 'Domingo 1 - Windows Server Core Infrastructure'
---

# LAB03 - Estruturar a CONTOSO no Active Directory

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB03 | AD DS (OUs, utilizadores, grupos, computadores), RSAT | 90 min | 1 |

## O problema

O domínio existe, mas está vazio. A CONTOSO tem **50 colaboradores em 5 departamentos** e o RH enviou a lista numa folha de cálculo. Se os utilizadores forem criados todos no contentor `Users`, não será possível aplicar regras diferentes ao Financeiro e ao Marketing, nem delegar ao Suporte o reset de palavras-passe sem lhe dar poder de administrador.

Além disso, os servidores e postos de trabalho ainda estão fora do domínio.

## O que este lab resolve

A CONTOSO fica com uma **estrutura de OUs que espelha a organização**, os **50 utilizadores criados automaticamente** a partir do ficheiro do RH (com departamento e cargo preenchidos), **grupos por departamento**, contas administrativas separadas e **todos os computadores juntos ao domínio** e arrumados na OU certa. Esta estrutura é a base das GPOs (LAB04), das permissões (LAB05) e do filtro de sincronização para a cloud (LAB08).

## Objectivos

- Desenhar e criar uma estrutura de OUs.
- Criar utilizadores e grupos manualmente e em massa com PowerShell.
- Separar contas de utilizador e contas de administração.
- Juntar servidores e clientes ao domínio e movê-los para OUs.
- Gerir o AD remotamente a partir do ADM01 (RSAT).

## Pré-requisitos

- [LAB02](LAB_02_Criar_Domain_Controller.md) concluído.
- VMs a ligar: **CMB31-DC01, CMB31-SRV01, CMB31-ADM01, CMB31-CL01**.
- Ficheiros: `Allfiles/Labs/03/contoso-users.csv` e `Import-ContosoUsers.ps1`.

## Topologia: estrutura de OUs

```text
corp.contoso.com
└── _CONTOSO
    ├── Admins            contas administrativas (adm.*)
    ├── Computadores
    │   └── Postos        CMB31-CL01
    ├── Grupos            GG_TI, GG_Financeiro, GG_RH, GG_Marketing, GG_Vendas,
    │                     GG_Direccao, GG_Helpdesk, GG_Todos
    ├── Servidores        CMB31-SRV01, CMB31-ADM01
    └── Utilizadores
        ├── TI  ├── Financeiro  ├── RH  ├── Marketing  └── Vendas
```

> **Porquê o prefixo `_`?** A OU `_CONTOSO` aparece sempre no topo das consolas e separa claramente os objectos da empresa dos contentores por omissão do Windows. Os **Domain Controllers ficam sempre na OU `Domain Controllers`**: nunca os mova.

## Credenciais

`CONTOSO\Administrator` / `Pa55w.rd2027!`. Utilizadores criados: palavra-passe `Contoso#2027`.

---

## Exercício 1: Juntar os servidores ao domínio

### Tarefa 1: Juntar o ADM01 e instalar o RSAT

1. No **CMB31-ADM01**, PowerShell como Administrador:

   ```powershell
   Add-Computer -DomainName corp.contoso.com -Credential CONTOSO\Administrator -Restart
   ```

1. Inicie sessão como `CONTOSO\Administrator` e instale as ferramentas de administração remota:

   ```powershell
   Install-WindowsFeature RSAT-AD-Tools, RSAT-DNS-Server, GPMC, RSAT-DHCP
   ```

> A partir de agora, **administre o AD a partir do ADM01**, não do DC. É uma boa prática: o DC só deve correr serviços de domínio.

### Tarefa 2: Juntar o SRV01 (Server Core) remotamente

1. No **ADM01**:

   ```powershell
   $local = Get-Credential -UserName 'CMB31-SRV01\Administrator' -Message 'Credencial local do SRV01'
   $dom   = Get-Credential -UserName 'CONTOSO\Administrator' -Message 'Credencial do domínio'
   Add-Computer -ComputerName 10.31.10.20 -LocalCredential $local -DomainName corp.contoso.com -Credential $dom -Restart -Force
   ```

1. Aguarde 1 minuto e confirme:

   ```powershell
   Get-ADComputer -Filter * | Select-Object Name, DistinguishedName
   ```

   Os servidores aparecem no contentor `CN=Computers`. Vai movê-los no Exercício 3.

1. Remova a entrada TrustedHosts do LAB01: já não é necessária, agora o domínio usa Kerberos.

   ```powershell
   Clear-Item WSMan:\localhost\Client\TrustedHosts -Force
   Enter-PSSession -ComputerName CMB31-SRV01    # sem -Credential: Kerberos
   Exit-PSSession
   ```

---

## Exercício 2: Criar a estrutura da CONTOSO

### Tarefa 3: Criar uma OU e um utilizador manualmente

Faça primeiro à mão para perceber o que o script vai automatizar.

1. No ADM01 abra **Active Directory Administrative Center** (`dsac.exe`).
1. Botão direito em **corp (local)** > **New > Organizational Unit** > nome `_CONTOSO`. Repare na opção **Protect from accidental deletion** (deixe marcada).
1. Dentro de `_CONTOSO`, crie a OU `Admins`.
1. Em `Admins`, crie o utilizador:
   - Nome: `ADM Nádia Sebastião`, logon: `adm.nadia`, palavra-passe `Pa55w.rd2027!`, **Password never expires** desmarcado.
1. Adicione `adm.nadia` ao grupo **Domain Admins**.

> **Porquê uma conta separada?** A Nádia usa `nadia.sebastiao` para e-mail e Internet, e `adm.nadia` **só** para administrar. Se a conta do dia-a-dia for comprometida por phishing, o atacante não ganha privilégios de administrador.

### Tarefa 4: Criar o resto em massa com PowerShell

1. Copie a pasta `Allfiles\Labs\03` do repositório para `C:\Labfiles\03` no **ADM01** (pode arrastar o ficheiro para a janela da VM com **Enhanced Session**, ou usar `Copy-VMFile` no portátil).
1. Abra o CSV no Bloco de Notas e observe as colunas: `FirstName, LastName, SamAccountName, Department, Title, Office, Company`.
1. Leia o script `Import-ContosoUsers.ps1` **antes** de o executar. Identifique onde cria as OUs, os grupos e os utilizadores.
1. Execute:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   cd C:\Labfiles\03
   .\Import-ContosoUsers.ps1
   ```

1. Resultado esperado no fim:

   | Name | Count |
   |---|---|
   | TI | 6 |
   | Financeiro | 8 |
   | RH | 6 |
   | Marketing | 10 |
   | Vendas | 20 |

1. Execute o script **uma segunda vez**. Repare que não cria duplicados: um bom script é **idempotente**.

### Tarefa 5: Explorar o resultado

1. Liste os directores e os seus grupos:

   ```powershell
   Get-ADGroupMember GG_Direccao | Select-Object Name
   Get-ADUser helena.matos -Properties Department, Title, MemberOf | Select-Object Name, Department, Title, MemberOf
   ```

1. Procure todos os utilizadores do Financeiro por **atributo**, não por OU:

   ```powershell
   Get-ADUser -Filter "Department -eq 'Financeiro'" | Measure-Object
   ```

> Os atributos **Department** e **Title** vão ser reutilizados no Microsoft 365 (grupos dinâmicos, LAB08). Dados bem preenchidos no AD poupam trabalho na cloud.

---

## Exercício 3: Computadores

### Tarefa 6: Mover os servidores para a OU certa

1. No ADM01:

   ```powershell
   $srvOU = 'OU=Servidores,OU=_CONTOSO,DC=corp,DC=contoso,DC=com'
   'CMB31-SRV01','CMB31-ADM01' | ForEach-Object { Get-ADComputer $_ | Move-ADObject -TargetPath $srvOU }
   ```

### Tarefa 7: Pré-configurar o destino dos novos computadores

Por omissão, cada computador novo cai em `CN=Computers`, onde nenhuma GPO da CONTOSO se aplica. Vamos mudar o destino por omissão para `_CONTOSO\Computadores\Postos`.

1. No ADM01 (PowerShell como Administrador):

   ```powershell
   redircmp 'OU=Postos,OU=Computadores,OU=_CONTOSO,DC=corp,DC=contoso,DC=com'
   ```

### Tarefa 8: Juntar a CL01 ao domínio

1. Inicie sessão na **CMB31-CL01** como `labadmin`. No **Terminal (Administrador)**, primeiro corrija o DNS (pendente do LAB02):

   ```powershell
   $i = (Get-NetAdapter | Where-Object Status -eq 'Up').ifIndex
   Set-DnsClientServerAddress -InterfaceIndex $i -ServerAddresses 10.31.10.10
   Add-Computer -DomainName corp.contoso.com -Credential CONTOSO\Administrator -Restart
   ```

1. Após reiniciar, no ecrã de início de sessão escolha **Other user** e entre como `CONTOSO\patricia.lunda` / `Contoso#2027` (Marketing).
1. Abra a linha de comandos e execute `whoami /groups | findstr GG_`. Deve ver `CONTOSO\GG_Marketing` e `CONTOSO\GG_Todos`.
1. No ADM01, confirme que a CL01 caiu **directamente** na OU `Postos`:

   ```powershell
   Get-ADComputer CMB31-CL01 | Select-Object DistinguishedName
   ```

### Tarefa 9: Delegar o reset de palavras-passe ao Helpdesk

O Suporte (GG_Helpdesk) deve conseguir **repor palavras-passe** dos utilizadores, mas **não** criar nem apagar contas.

1. No ADM01 abra **Active Directory Users and Computers** (`dsa.msc`).
1. Botão direito na OU **_CONTOSO > Utilizadores** > **Delegate Control** > **Next**.
1. **Add** > `GG_Helpdesk` > **Next**.
1. Marque **Reset user passwords and force password change at next logon** > **Next > Finish**.
1. Teste no ADM01 com a identidade do Edson (membro de GG_Helpdesk). Numa linha de comandos execute `runas /user:CONTOSO\edson.lukeny powershell` (palavra-passe `Contoso#2027`) e, na nova janela:

   ```powershell
   Set-ADAccountPassword -Identity tiago.muxima -Reset -NewPassword (ConvertTo-SecureString 'Contoso#2027b' -AsPlainText -Force)   # deve funcionar
   Remove-ADUser -Identity tiago.muxima                                                                                        # deve falhar: Access is denied
   ```

1. Feche a janela do Edson e, como `CONTOSO\Administrator`, reponha a palavra-passe do Tiago para `Contoso#2027`.

> **Alternativa sem executar comandos:** propriedades da OU **Utilizadores** > **Security > Advanced > Effective Access** > seleccione `edson.lukeny` e veja que permissões tem.

### Tarefa 10: Checkpoint

```powershell
# No portátil
Get-VM -Name 'CMB31-DC01','CMB31-SRV01','CMB31-ADM01','CMB31-CL01' | Checkpoint-VM -SnapshotName '03-Dominio-Estruturado'
```

---

## Evidência de conclusão

Guarde em `Evidencias\LAB03`:

1. Captura do ADAC/ADUC com a árvore `_CONTOSO` expandida.
1. Saída da tabela de contagem por departamento.
1. Saída de `Get-ADComputer -Filter * | Select Name, DistinguishedName`.
1. Captura do `Access is denied` ao tentar apagar um utilizador com a conta do Helpdesk.

## Validação

- [ ] Estrutura `_CONTOSO` com as OUs da topologia.
- [ ] 50 utilizadores nas OUs de departamento, com Department e Title preenchidos.
- [ ] 8 grupos `GG_*` com os membros correctos.
- [ ] Conta `adm.nadia` em Domain Admins, na OU `Admins`.
- [ ] SRV01 e ADM01 na OU `Servidores`; CL01 na OU `Postos`.
- [ ] Helpdesk consegue repor palavras-passe mas não apagar contas.

## Troubleshooting

| Erro | Causa | Solução |
|---|---|---|
| `Add-Computer`: *"The specified domain either does not exist or could not be contacted"* | DNS da máquina não aponta para o DC | `Set-DnsClientServerAddress ... 10.31.10.10` e `nslookup corp.contoso.com`. |
| Script: *"cannot be loaded because running scripts is disabled"* | Execution Policy | `Set-ExecutionPolicy -Scope Process Bypass -Force`. |
| Script: nomes com acentos aparecem estragados | Codificação do CSV | O CSV está em UTF-8 com BOM; não o abra nem grave no Excel. |
| Não consigo apagar uma OU de teste | Protecção contra eliminação acidental | Em ADUC: **View > Advanced Features**, propriedades da OU > **Object** > desmarcar a protecção. |
| Utilizador não consegue entrar na CL01 | Escreveu só o nome | Use `CONTOSO\utilizador` ou `utilizador@corp.contoso.com`. |

## Challenge

A CONTOSO contratou uma nova colaboradora para Vendas, **Zélia Kanda**. Com **um único comando PowerShell**, crie-a na OU certa, com departamento, cargo `Vendedora`, palavra-passe que **tem de ser mudada no primeiro login**, e membro de `GG_Vendas` e `GG_Todos`.

## Cleanup

Nada a limpar. A estrutura é usada em todos os labs seguintes.

## Resultado esperado

O AD reflecte a CONTOSO real: 50 pessoas organizadas por departamento, grupos prontos para permissões e políticas, computadores no domínio e no lugar certo, e o Suporte com o poder exacto de que precisa, nem mais nem menos. **Fim do Domingo 1.**

**Próximo lab:** [LAB04 - Group Policy](LAB_04_Group_Policy.md)
