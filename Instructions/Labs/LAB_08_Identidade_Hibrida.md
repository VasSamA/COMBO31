---
lab:
    title: 'LAB08 - Identidade híbrida com Microsoft Entra Connect Sync'
    module: 'Domingo 3 - Microsoft 365 Identity & Access'
---

# LAB08 - Identidade híbrida com Microsoft Entra Connect Sync

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB08 | Microsoft Entra Connect Sync, Password Hash Sync, group-based licensing | 105 min | 3 |

## O problema

A CONTOSO tem agora **duas ilhas**: 50 utilizadores no Active Directory local e um tenant Microsoft 365 vazio. Criar as 50 contas outra vez na cloud significaria:

- **Duas palavras-passe por pessoa**, que vão divergir e gerar chamadas para o Suporte.
- Quando alguém sai da empresa, o RH desactiva a conta no AD mas **a conta cloud continua activa**, com acesso ao e-mail e aos ficheiros.
- Departamento e cargo actualizados num sítio e não no outro.

*"O AD é a fonte da verdade. A cloud tem de o seguir automaticamente."* - Paulo Kiala, Director de TI.

## O que este lab resolve

A CONTOSO passa a ter **identidade híbrida**: os utilizadores e grupos das OUs da empresa são **sincronizados automaticamente** do AD para o Microsoft Entra ID, com **a mesma palavra-passe** (Password Hash Sync) e com **escrita de palavras-passe de volta para o AD** (preparação do SSPR no LAB09). As licenças passam a ser atribuídas **por grupo do AD**: entrar no grupo dá licença, sair retira-a.

## Objectivos

- Preparar o AD para a sincronização (sufixo UPN, atributos, filtro de OUs).
- Instalar e configurar o **Microsoft Entra Connect Sync** com Password Hash Sync e Password Writeback.
- Validar a sincronização e forçar ciclos delta.
- Compreender a **fonte de autoridade** (onde se edita cada atributo).
- Atribuir licenças por grupo sincronizado.

## Pré-requisitos

- [LAB03](LAB_03_Estruturar_a_CONTOSO.md) e [LAB07](LAB_07_Tenant_e_Dominio.md) concluídos.
- VMs a ligar: **CMB31-DC01, CMB31-ADM01** (ADM01 com **4 GB de RAM**), CL01 opcional.
- Conta `admin@<tenant>` (Global Administrator) com MFA registado.

## Topologia

```text
 AD: corp.contoso.com                          Microsoft Entra ID: <tenant>.onmicrosoft.com
 ┌─────────────────────────────┐               ┌───────────────────────────────┐
 │ _CONTOSO\Utilizadores (50)  │──┐            │ 50 utilizadores "híbridos"    │
 │ _CONTOSO\Grupos (GG_, DL_)  │  │  HTTPS 443 │ grupos GG_*                   │
 └─────────────────────────────┘  ├──────────▶ │ hash da palavra-passe (PHS)   │
            ▲                     │            └───────────────────────────────┘
            │ password writeback  │                         │
            └──────────── CMB31-ADM01 ◀──────────────────────┘
                   Microsoft Entra Connect Sync (a cada 30 min)
```

> **Porque no ADM01 e não no SRV01?** O Entra Connect Sync **exige servidor com interface gráfica completa**; Server Core não é suportado. Em produção, o servidor do Entra Connect é tratado como **Tier 0** (tão crítico como um DC).

> **`Actualização 2026/2027`:** o **Microsoft Entra Cloud Sync** (agente leve, configuração na cloud) é a alternativa recomendada pela Microsoft para muitos cenários novos. Neste curso usamos o **Connect Sync** porque ainda é o mais encontrado nos clientes e porque o agente de Cloud Sync ainda não suporta Windows Server 2025. Os conceitos (PHS, filtros, fonte de autoridade) são os mesmos.

## Credenciais

`CONTOSO\Administrator` / `Pa55w.rd2027!` (Enterprise Admin) | `admin@<tenant>.onmicrosoft.com` | utilizadores `Contoso#2027`.

---

## Exercício 1: Preparar o Active Directory

### Tarefa 1: Analisar o UPN dos utilizadores

1. No **ADM01**:

   ```powershell
   Get-ADUser -Filter * -SearchBase 'OU=Utilizadores,OU=_CONTOSO,DC=corp,DC=contoso,DC=com' |
       Select-Object -First 5 SamAccountName, UserPrincipalName
   ```

1. Os UPN são `nome@corp.contoso.com`. Este sufixo **não pode ser verificado** no tenant (não controlamos `contoso.com`). Resultado: na sincronização, o Entra substitui automaticamente o sufixo por `@<tenant>.onmicrosoft.com`. **É aceitável para o laboratório.**

> **Com domínio próprio verificado (Tarefa 6 do LAB07)?** Adicione-o como sufixo UPN e actualize os utilizadores antes de sincronizar:
>
> ```powershell
> Get-ADForest | Set-ADForest -UPNSuffixes @{Add='seudominio.ao'}
> Get-ADUser -Filter * -SearchBase 'OU=Utilizadores,OU=_CONTOSO,DC=corp,DC=contoso,DC=com' |
>     ForEach-Object { Set-ADUser $_ -UserPrincipalName "$($_.SamAccountName)@seudominio.ao" }
> ```

### Tarefa 2: Verificar a saúde dos atributos

1. Confirme que não existem duplicados de `mail` e `UserPrincipalName` (causa n.º 1 de erros de sincronização):

   ```powershell
   Get-ADUser -Filter * -Properties mail | Group-Object mail | Where-Object Count -gt 1
   Get-ADUser -Filter * | Group-Object UserPrincipalName | Where-Object Count -gt 1
   ```

   Ambos devem devolver **nada**. Em ambientes reais, usa-se a ferramenta **IdFix** da Microsoft para esta análise.

---

## Exercício 2: Instalar o Microsoft Entra Connect Sync

### Tarefa 3: Descarregar

1. No **ADM01**, entre em `https://entra.microsoft.com` com `admin@<tenant>`.
1. **Identity > Hybrid management > Microsoft Entra Connect > Connect Sync** > **Download Microsoft Entra Connect**.
1. Guarde o instalador `AzureADConnect.msi` (o nome histórico mantém-se).

### Tarefa 4: Instalação personalizada

1. Execute o instalador. Aceite os termos.
1. Em **Express Settings**, escolha **Customize** (queremos controlar o filtro de OUs).
1. **Install required components:** deixe tudo desmarcado > **Install**.
1. **User sign-in:** **Password Hash Synchronization**. Não marque *Enable single sign-on*.
1. **Connect to Microsoft Entra ID:** entre com `admin@<tenant>.onmicrosoft.com` e aprove o MFA.
1. **Connect your directories:** a floresta `corp.contoso.com` > **Add Directory** > **Create new AD account** > `CONTOSO\Administrator` / `Pa55w.rd2027!`.
1. **Microsoft Entra sign-in configuration:** o sufixo `corp.contoso.com` aparece como **Not Added/Not Verified**. Marque **Continue without matching all UPN suffixes to verified domains** > **Next**.
1. **Domain and OU filtering:** **Sync selected domains and OUs**. Desmarque tudo e marque **apenas**:
   - `_CONTOSO > Utilizadores`
   - `_CONTOSO > Grupos`

   > **Porquê filtrar?** Contas de serviço, administradores (`_CONTOSO\Admins`) e objectos de sistema **não devem** ir para a cloud. As contas `adm.*` ficam só no AD; na cloud usam-se contas de administração cloud-only (LAB07).

1. **Uniquely identifying your users:** deixe os valores por omissão.
1. **Filter users and devices:** **Synchronize all users and devices**.
1. **Optional features:** marque **Password writeback**. (Necessário para o SSPR do LAB09: quando um utilizador repõe a palavra-passe na cloud, a nova palavra-passe é escrita no AD.)
1. **Ready to configure:** confirme **Start the synchronization process when configuration completes** > **Install**.
1. Aguarde o fim. Leia os avisos finais (são informativos).

---

## Exercício 3: Validar a sincronização

### Tarefa 5: Ver os utilizadores na cloud

1. Em `https://entra.microsoft.com` > **Identity > Users > All users**. Adicione a coluna **On-premises sync enabled**.
1. Devem existir **50 utilizadores** com **Yes**, mais as contas cloud do LAB07 com **No**.
1. Abra `Helena Matos`: veja **Department = Financeiro**, **Job title = Directora Financeira** e o UPN `helena.matos@<tenant>.onmicrosoft.com`.
1. **Identity > Groups > All groups:** os grupos `GG_*` e `DL_FS_*` aparecem com origem **Windows Server AD**.

### Tarefa 6: Forçar e observar um ciclo

1. No **ADM01**, PowerShell como Administrador:

   ```powershell
   Import-Module ADSync
   Get-ADSyncScheduler | Select-Object SyncCycleEnabled, CurrentlyEffectiveSyncCycleInterval, NextSyncCycleStartTimeInUTC
   ```

   O ciclo automático corre a cada **30 minutos**.

1. Altere um atributo no AD e force um ciclo **delta**:

   ```powershell
   Set-ADUser adilson.cassoma -Title 'Contabilista Sénior'
   Start-ADSyncSyncCycle -PolicyType Delta
   ```

1. Após 1-2 minutos, confirme no Entra que o cargo do Adilson mudou.

### Tarefa 7: Fonte de autoridade

1. No Entra, tente **editar o Job title** da Helena Matos. O campo está **bloqueado**: o objecto é gerido pelo AD local.
1. Agora desactive a conta no AD e sincronize:

   ```powershell
   Disable-ADAccount sandra.fortunato
   Start-ADSyncSyncCycle -PolicyType Delta
   ```

1. No Entra, a Sandra aparece com **Account enabled = No**. A saída de um colaborador passa a ser tratada **num único sítio**.
1. Volte a activar: `Enable-ADAccount sandra.fortunato` e novo ciclo delta.

### Tarefa 8: Provar a mesma palavra-passe (PHS)

1. Numa janela privada, entre em `https://myaccount.microsoft.com` como `paulo.kiala@<tenant>.onmicrosoft.com` com a palavra-passe **do AD**: `Contoso#2027`.
1. Como os Security defaults ainda estão activos, será pedido o registo do Authenticator. Pode escolher **Skip for now** (há um período de tolerância) ou registar.
1. Entrou com a palavra-passe do AD. **Uma identidade, uma palavra-passe.**

> **Ponto de atenção:** o hash que vai para a cloud **não é** o hash NTLM do AD: é um hash do hash, com sal e milhares de iterações. Mesmo que fosse roubado da cloud, não serve para autenticar no AD.

---

## Exercício 4: Licenças por grupo

O trial tem **25 licenças** e a CONTOSO tem 50 pessoas. A direcção decidiu um **piloto** com TI, Financeiro e RH (6 + 8 + 6 = 20 pessoas).

### Tarefa 9: Atribuir licenças a grupos sincronizados

1. Em `https://entra.microsoft.com` > **Identity > Billing > Licenses > All products > Microsoft 365 Business Premium > + Assign**.
1. **Add users and groups:** `GG_TI`, `GG_Financeiro`, `GG_RH` > **Assign**.
1. Após alguns minutos, em **Licensed groups**, cada grupo deve mostrar **Active** sem erros. Em `admin.microsoft.com > Billing > Licenses` deve ver **22 de 25** atribuídas (20 + admin/teste conforme o seu tenant).

> As licenças são atribuídas por **grupo**, não por OU. Quando o RH mover alguém para o Financeiro no AD (alterando a pertença ao grupo), a licença acompanha automaticamente.

### Tarefa 10: Ver um erro de licenciamento (de propósito)

1. Atribua também a licença a `GG_Vendas` (20 pessoas).
1. Abra o grupo em **Licensed groups**: vai ver **erros "Not enough licenses"** para parte dos membros.
1. **Remova** a atribuição a `GG_Vendas`. Na vida real, este é o momento de comprar licenças ou rever o piloto.

### Tarefa 11: Checkpoint

```powershell
# No portátil
Get-VM -Name 'CMB31-DC01','CMB31-ADM01' | Checkpoint-VM -SnapshotName '08-Hibrido'
```

---

## Evidência de conclusão

Guarde em `Evidencias\LAB08`:

1. Captura de **All users** no Entra com a coluna **On-premises sync enabled**.
1. Saída do `Get-ADSyncScheduler`.
1. Captura do Job title do Adilson actualizado no Entra.
1. Captura de **Licensed groups** com GG_TI, GG_Financeiro e GG_RH.

## Validação

- [ ] Entra Connect Sync instalado no ADM01 com PHS e Password writeback.
- [ ] Só as OUs `Utilizadores` e `Grupos` sincronizam (as contas `adm.*` **não** existem no Entra).
- [ ] Alterações no AD chegam ao Entra num ciclo delta.
- [ ] Utilizador sincronizado entra na cloud com a palavra-passe do AD.
- [ ] 20 utilizadores licenciados por grupo, sem erros.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| Instalador falha a ligar ao Entra | MFA/browser bloqueado no servidor | Use o Edge do ADM01; confirme hora correcta (`w32tm /resync`). |
| Utilizadores não aparecem | OU não seleccionada no filtro | Reabra o **Microsoft Entra Connect Sync** > **Customize synchronization options** > **Domain and OU filtering**. |
| Erro de duplicado (*AttributeValueMustBeUnique*) | `mail`/`proxyAddresses`/UPN repetido | Corrija no AD e faça novo ciclo. Veja **Entra > Hybrid management > Connect Health > Sync errors** (ou o **Synchronization Service Manager**). |
| Contas `adm.*` apareceram no Entra | OU `Admins` sincronizada | Retire do filtro; serão apagadas da cloud no ciclo seguinte. |
| Licença com erro *"usage location"* | Tenant sem país definido | Defina **Usage location** nos utilizadores ou confirme o país do tenant. |
| Login cloud falha com a palavra-passe do AD | PHS ainda não correu | Aguarde 2-5 min ou `Start-ADSyncSyncCycle -PolicyType Initial`. |

## Challenge

1. Crie no Entra um **grupo dinâmico** `DYN-Vendas` com a regra `user.department -eq "Vendas"` e confirme que contém os 20 vendedores **sem ninguém os adicionar**. (Funciona porque o atributo Department veio do AD.)
1. Mova o `edson.lukeny` do grupo `GG_TI` para `GG_Vendas` no AD, sincronize e explique o que aconteceu à **licença** e ao **grupo dinâmico**.

## Cleanup

Nada a limpar. A sincronização continua a correr; mantenha o ADM01 ligado sempre que trabalhar nos labs de Microsoft 365.

## Resultado esperado

A CONTOSO tem uma identidade única: o AD manda, a cloud segue. Os colaboradores usam a mesma palavra-passe em todo o lado e as licenças acompanham os grupos. Falta proteger esta identidade, agora exposta na Internet.

**Próximo lab:** [LAB09 - MFA + Conditional Access](LAB_09_MFA_e_Conditional_Access.md)
