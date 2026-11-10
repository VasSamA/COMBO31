---
lab:
    title: 'LAB13 - Azure Governance'
    module: 'Domingo 5 - Microsoft Azure Infrastructure'
---

# LAB13 - Azure Governance

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB13 | Management Groups, Subscription, Resource Groups, Tags, Azure Policy, RBAC, Locks, Cost Management | 105 min | 5 |

## O problema

A CONTOSO vai começar a usar o Azure. O Director de TI já viu o que acontece noutras empresas:

- Recursos criados em regiões do outro lado do mundo, com nomes como `teste123` e `vm-nova-final2`.
- Uma factura de USD 3.000 no fim do mês **sem ninguém saber quem criou o quê**.
- Um estagiário com permissões de Owner que apagou a rede de produção.

*"Antes de criarmos a primeira VM, quero regras: onde, com que nome, quem paga, quem pode mexer e um alarme quando o dinheiro começar a fugir."*

## O que este lab resolve

A subscription da CONTOSO fica **governada antes de existir qualquer carga de trabalho**: hierarquia de Management Groups, Resource Groups com **convenção de nomes e tags**, **Azure Policy** que impede regiões não autorizadas e recursos sem centro de custo, **RBAC** com privilégio mínimo para os utilizadores sincronizados do AD, **Locks** contra eliminação acidental e um **budget com alertas**.

## Objectivos

- Activar a subscription no tenant da CONTOSO e usar o Cloud Shell.
- Criar Management Groups e organizar a subscription.
- Criar Resource Groups com nomes e tags padronizados.
- Atribuir Azure Policies (built-in e personalizada) e ver o efeito Deny/Audit.
- Atribuir papéis RBAC e testar com outro utilizador.
- Aplicar um Resource Lock.
- Criar um budget com alertas.

## Pré-requisitos

- [LAB07](LAB_07_Tenant_e_Dominio.md) concluído (e [LAB08](LAB_08_Identidade_Hibrida.md) para testar RBAC com utilizadores sincronizados).
- **Uma das opções:**
  - **[Subscription própria]** Conta Azure gratuita activada com `admin@<tenant>` (recomendado).
  - **Subscription da academia:** o instrutor dá-lhe o papel **Owner** num Resource Group. Ignore as tarefas marcadas **[Subscription própria]** e aplique as Policies e o budget **ao nível do seu RG**.
- Ficheiros: `Allfiles/Labs/13/policy-naming-rg-contoso.json` e `role-vm-operator-contoso.json`.

## Topologia

```text
Tenant Root Group
└── mg-contoso
    └── mg-contoso-lab
        └── Subscription (Azure gratuita ou academia)
            ├── rg-contoso-net-<ini>    rede (LAB14)        [Lock: CanNotDelete]
            ├── rg-contoso-app-<ini>    VMs (LAB14)
            ├── rg-contoso-data-<ini>   storage (LAB15)
            └── rg-contoso-ops-<ini>    monitor/backup (LAB16-17)
Tags obrigatórias: Projecto=COMBO | Ambiente=Lab | Dono=<ini> | CentroCusto=TI
Regiões permitidas: a região do curso (ex.: northeurope) + southafricanorth
```

### Convenção de nomes da CONTOSO

| Recurso | Padrão | Exemplo |
|---|---|---|
| Resource Group | `rg-contoso-<função>-<ini>` | `rg-contoso-net-osm` |
| Virtual Network | `vnet-contoso-<função>-<ini>` | `vnet-contoso-app-osm` |
| Subnet | `snet-<função>` | `snet-app` |
| NSG | `nsg-<subnet>-<ini>` | `nsg-snet-app-osm` |
| VM | `vm-contoso-<função><nn>` | `vm-contoso-app01` |
| Storage account | `stcontoso<ini><nn>` (só minúsculas e números) | `stcontosoosm01` |
| Log Analytics | `law-contoso-<ini>` | `law-contoso-osm` |
| Recovery Services vault | `rsv-contoso-<ini>` | `rsv-contoso-osm` |

> **Região do curso:** use a região indicada pelo instrutor. Se estiver sozinho(a), escolha uma região que suporte **Azure Bastion Developer** (lista na documentação "Bastion configuration settings") e onde a sua subscription tenha quota de VMs da série B. Neste guia usamos `northeurope` como exemplo: substitua sempre que necessário.

## Credenciais

`admin@<tenant>` (Owner da subscription) | `paulo.kiala@<tenant>`, `nadia.sebastiao@<tenant>` (sincronizados no LAB08).

---

## Exercício 1: Subscription e ferramentas

### Tarefa 1: Activar a subscription **[Subscription própria]**

1. Numa janela privada, abra `https://azure.microsoft.com/free` e seleccione **Start free / Try Azure for free**.
1. Entre com **`admin@<tenant>.onmicrosoft.com`** (e não com uma conta pessoal). Assim a subscription fica no **mesmo Microsoft Entra ID** do Microsoft 365, onde já estão os utilizadores da CONTOSO.
1. Complete a verificação (telemóvel e cartão). A conta gratuita **não cobra** sem que faça upgrade explícito para Pay-As-You-Go.
1. Abra `https://portal.azure.com` > **Subscriptions** e anote o **Subscription ID**.

> **Porque é que o tenant importa?** Uma subscription confia **num único** Entra ID. Se activar o Azure com uma conta pessoal, cria um tenant novo e vazio, e os utilizadores da CONTOSO não existirão lá para receber permissões.

### Tarefa 2: Cloud Shell

1. No portal, ícone **Cloud Shell** (`>_`) na barra superior > **PowerShell**.
1. Se pedir armazenamento, escolha **No storage account required** (sessão efémera) e a sua subscription.
1. Execute:

   ```powershell
   Get-AzContext | Select-Object Account, Subscription, Tenant
   Get-AzLocation | Where-Object Name -in 'northeurope','southafricanorth' | Select-Object Location, DisplayName
   ```

1. Defina variáveis que vai reutilizar em todos os labs Azure (repita no início de cada sessão do Cloud Shell):

   ```powershell
   $ini = 'osm'            # as suas iniciais, minúsculas
   $loc = 'northeurope'    # região do curso
   $tags = @{ Projecto='COMBO'; Ambiente='Lab'; Dono=$ini; CentroCusto='TI' }
   ```

---

## Exercício 2: Organizar

### Tarefa 3: Management Groups **[Subscription própria]**

1. Portal > **Management groups** > **Create**: ID `mg-contoso`, nome `CONTOSO`.
1. Dentro de `mg-contoso`, crie `mg-contoso-lab` (nome `CONTOSO Laboratório`).
1. Abra `mg-contoso-lab` > **Subscriptions > Add** > a sua subscription.

> Políticas e permissões atribuídas a um Management Group **herdam** para todas as subscriptions debaixo dele. Numa empresa com várias subscriptions (produção, desenvolvimento), é aqui que se põem as regras comuns.

### Tarefa 4: Resource Groups com tags

1. No Cloud Shell:

   ```powershell
   'net','app','data','ops' | ForEach-Object {
       New-AzResourceGroup -Name "rg-contoso-$_-$ini" -Location $loc -Tag $tags
   }
   Get-AzResourceGroup | Where-Object ResourceGroupName -like 'rg-contoso-*' | Select-Object ResourceGroupName, Location, Tags
   ```

---

## Exercício 3: Azure Policy

### Tarefa 5: Regiões permitidas (Deny)

1. Portal > **Policy > Assignments > Assign policy**.
   - **Scope:** `mg-contoso` (ou o seu RG, na subscription da academia).
   - **Policy definition:** pesquise `Allowed locations` (built-in).
   - **Assignment name:** `CONTOSO - Regioes permitidas`.
   - **Parameters:** seleccione a região do curso e **South Africa North**.
   - **Non-compliance message:** `A CONTOSO só permite recursos nas regiões aprovadas.`
   - **Review + create**.
1. Repita para `Allowed locations for resource groups` com os mesmos valores.

### Tarefa 6: Tag obrigatória (Deny)

1. Atribua a policy built-in **Require a tag on resource groups**, scope `mg-contoso`, parâmetro **Tag Name** = `CentroCusto`. Mensagem: `Todos os Resource Groups precisam da tag CentroCusto.`
1. Atribua a policy built-in **Inherit a tag from the resource group if missing**, parâmetro `CentroCusto`. No separador **Remediation**, marque **Create a Managed Identity** (o efeito *Modify* precisa dela).

> **Ponto de atenção (vai senti-lo nos próximos labs):** alguns serviços do Azure criam Resource Groups **automaticamente** e sem tags, por exemplo `NetworkWatcherRG` (LAB14) e `AzureBackupRG_...` (LAB17). Com esta policy em *Deny*, essa criação automática **falha**. Não é um erro do lab: é governance real a funcionar. Os labs seguintes mostram como trabalhar com ela (pré-criar o RG com tags e indicar o nome ao serviço).

### Tarefa 7: Policy personalizada de nomes (Audit)

1. **Policy > Definitions > + Policy definition**:
   - **Definition location:** `mg-contoso`.
   - **Name:** `CONTOSO - Convencao de nomes de RG`. **Category:** Create new `CONTOSO Governance`.
   - **Policy rule:** apague o conteúdo e cole o ficheiro `policy-naming-rg-contoso.json`.
   - **Save**.
1. Atribua-a a `mg-contoso` com **Effect = Audit**.

> **Audit vs Deny:** *Deny* bloqueia. *Audit* deixa criar mas marca como **não conforme**. A CONTOSO usa *Audit* para nomes porque alguns serviços do Azure criam RGs automáticos (ex.: `NetworkWatcherRG`) que não seguem a convenção; bloqueá-los partiria esses serviços.

### Tarefa 8: Provar que funciona

Aguarde **5-10 minutos** (as atribuições demoram a ficar activas) e, no Cloud Shell:

```powershell
# 1. Região não permitida -> deve falhar com RequestDisallowedByPolicy
New-AzResourceGroup -Name "rg-contoso-teste-$ini" -Location 'japaneast' -Tag $tags

# 2. Sem tag CentroCusto -> deve falhar
New-AzResourceGroup -Name "rg-contoso-teste-$ini" -Location $loc -Tag @{ Projecto='COMBO' }

# 3. Nome fora da convenção -> é criado, mas fica Non-compliant
New-AzResourceGroup -Name "teste123-$ini" -Location $loc -Tag $tags
```

1. Leia as mensagens de erro: indicam **qual** a policy e mostram a sua mensagem personalizada.
1. **Policy > Compliance:** após alguns minutos (ou forçando com `Start-AzPolicyComplianceScan -AsJob`), `teste123-<ini>` aparece como **Non-compliant**.
1. Elimine o RG de teste: `Remove-AzResourceGroup -Name "teste123-$ini" -Force`.

---

## Exercício 4: Quem pode fazer o quê

### Tarefa 9: RBAC para utilizadores sincronizados

| Pessoa | Papel | Scope | Porquê |
|---|---|---|---|
| Paulo Kiala (Director de TI) | **Reader** | Subscription (ou o seu RG) | Vê tudo, não altera nada |
| Nádia Sebastião (Administradora de Sistemas) | **Contributor** | `rg-contoso-app-<ini>` | Gere as VMs da aplicação |
| Nádia Sebastião | **Network Contributor** | `rg-contoso-net-<ini>` | Gere a rede |

1. No Cloud Shell:

   ```powershell
   $tenantDomain = (Get-AzTenant).Domains | Where-Object { $_ -like '*.onmicrosoft.com' } | Select-Object -First 1
   $sub = (Get-AzContext).Subscription.Id
   New-AzRoleAssignment -SignInName "paulo.kiala@$tenantDomain"     -RoleDefinitionName 'Reader'              -Scope "/subscriptions/$sub"
   New-AzRoleAssignment -SignInName "nadia.sebastiao@$tenantDomain" -RoleDefinitionName 'Contributor'         -ResourceGroupName "rg-contoso-app-$ini"
   New-AzRoleAssignment -SignInName "nadia.sebastiao@$tenantDomain" -RoleDefinitionName 'Network Contributor' -ResourceGroupName "rg-contoso-net-$ini"
   ```

   *(Na subscription da academia, atribua o Reader do Paulo ao seu RG em vez da subscription.)*

1. Numa janela privada, entre em `https://portal.azure.com` como `paulo.kiala`:
   - Vê os 4 RGs. Tente criar um Resource Group: **falha** (Reader).
1. Como `nadia.sebastiao`: consegue criar recursos em `rg-contoso-app-<ini>` mas **não** em `rg-contoso-data-<ini>`.

> **Ligação com o LAB09:** o portal do Azure exige MFA. Os utilizadores do piloto já têm Authenticator; a Nádia e o Paulo (GG_TI) também estão abrangidos pela CA003.

### Tarefa 10: Resource Lock

1. Portal > `rg-contoso-net-<ini>` > **Settings > Locks > + Add**: nome `lock-nao-apagar`, tipo **Delete**.
1. Tente eliminar o RG (Cloud Shell): `Remove-AzResourceGroup -Name "rg-contoso-net-$ini" -Force`. **Falha**, mesmo sendo Owner.

> RBAC controla **quem**; Locks protegem **o quê**, contra todos, incluindo administradores distraídos.

---

## Exercício 5: Custos

### Tarefa 11: Budget com alertas

1. Portal > **Cost Management + Billing > Cost Management > Budgets > + Add**.
   - **Scope:** a subscription (ou o seu RG).
   - Nome `budget-contoso-lab`, **Reset period** Monthly, **Amount** `20` (USD).
1. **Alert conditions:** *Actual* 50%, *Actual* 80%, *Forecasted* 100%. E-mail: o seu.
1. **Create**.
1. Explore **Cost analysis**: agrupe por **Resource group** e depois por **Tag: CentroCusto**. As tags do Exercício 2 tornam isto possível.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB13`:

1. Captura da hierarquia de Management Groups (ou do seu RG na academia).
1. Mensagens de erro `RequestDisallowedByPolicy` dos testes 1 e 2.
1. Captura de **Policy > Compliance** com o RG não conforme.
1. Saída de `Get-AzRoleAssignment -ResourceGroupName "rg-contoso-app-$ini"`.
1. Captura do erro ao apagar o RG com Lock.
1. Captura do budget.

## Validação

- [ ] Subscription no tenant da CONTOSO.
- [ ] 4 RGs `rg-contoso-*-<ini>` com as 4 tags.
- [ ] Policies: regiões (Deny), tag CentroCusto (Deny + Modify), nomes (Audit).
- [ ] Paulo = Reader; Nádia = Contributor/Network Contributor nos RGs certos.
- [ ] Lock no RG de rede.
- [ ] Budget de 20 USD com 3 alertas.

## Troubleshooting

| Sintoma | Solução |
|---|---|
| A policy não bloqueia | Aguarde até 30 min após a atribuição. |
| `New-AzRoleAssignment`: utilizador não encontrado | A subscription está noutro tenant (activada com conta pessoal). Ver Tarefa 1. Confirme o domínio com `Get-AzTenant`. |
| Não consigo criar Management Groups | Na subscription da academia é normal. Em subscription própria, confirme que é Owner. |
| O Paulo não vê nada no portal | Atribuições RBAC demoram até 5 min. Faça logout/login. |
| Budget indisponível | Contas gratuitas mostram dados de custo com atraso de 24-48h; o budget pode ser criado na mesma. |

## Challenge

1. Crie o **papel personalizado** `CONTOSO VM Operator` a partir de `role-vm-operator-contoso.json` (substitua `<ID-DA-SUBSCRIPTION>`) com `New-AzRoleDefinition -InputFile`. Atribua-o ao `edson.lukeny` (Suporte) no RG `rg-contoso-app-<ini>`. No LAB14, prove que ele consegue ligar e desligar a VM mas não a consegue apagar.
1. Agrupe as três policies num **Initiative** (`CONTOSO - Baseline de Governance`) e substitua as atribuições individuais por uma única atribuição da initiative.

## Cleanup

**Não apague nada.** Os RGs, policies, RBAC e o budget são usados nos LAB14 a LAB18.

## Resultado esperado

A cloud da CONTOSO tem regras antes de ter recursos: onde, com que nome, quem paga, quem mexe e um alarme quando o dinheiro começar a fugir.

**Próximo lab:** [LAB14 - VNet + VM](LAB_14_VNet_e_VM.md)
