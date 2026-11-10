---
lab:
    title: 'LAB18 - Segurança, Updates e automação'
    module: 'Domingo 6 - Azure Operations'
---

# LAB18 - Segurança, Updates e automação

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB18 | Microsoft Defender for Cloud, Azure Advisor, Azure Update Manager, Azure CLI, Azure PowerShell, Bicep | 105 min | 6 |

## O problema

A auditoria anual da CONTOSO chegou com três perguntas que ninguém soube responder:

1. *"A vossa cloud está configurada de acordo com as boas práticas de segurança? Como o provam?"*
1. *"Os servidores, no escritório e na cloud, têm as actualizações de segurança em dia?"*
1. *"Se a região do Azure falhar, quanto tempo demoram a recriar a infraestrutura? Está documentada?"*

Tudo o que a CONTOSO construiu foi feito **à mão no portal**. Se fosse preciso repetir, ninguém sabia exactamente como.

## O que este lab resolve

A CONTOSO passa a ter uma **medida contínua da postura de segurança** (Defender for Cloud Secure Score e recomendações), **recomendações de custo e fiabilidade** (Advisor), **gestão de actualizações** para a VM no Azure e para o servidor on-premises ligado pelo Arc (Update Manager), e dá o primeiro passo em **infraestrutura como código**: a rede de recuperação é criada a partir de um ficheiro **Bicep** versionado, repetível e revisível.

## Objectivos

- Rever o Secure Score e as recomendações do Defender for Cloud e corrigir uma.
- Usar o Azure Advisor.
- Avaliar e instalar actualizações com o Azure Update Manager.
- Administrar recursos com Azure CLI e Azure PowerShell.
- Fazer deploy de infraestrutura com Bicep, incluindo `what-if`.

## Pré-requisitos

- [LAB14](LAB_14_VNet_e_VM.md) e [LAB16](LAB_16_Azure_Monitor_e_Arc.md) concluídos (`vm-contoso-app01`, `CMB31-SRV01` no Arc).
- Ficheiro: `Allfiles/Labs/18/main.bicep`.
- Cloud Shell com `$ini`, `$loc`, `$tags`.

## Topologia

```text
Microsoft Defender for Cloud (Foundational CSPM, gratuito)
 ├── Secure Score + recomendações  ─▶ subscription / rg-contoso-*
 └── (opcional) Defender for Servers ─▶ vm-contoso-app01, CMB31-SRV01 (Arc)
Azure Advisor ─▶ custo, segurança, fiabilidade, desempenho
Azure Update Manager ─▶ vm-contoso-app01 (Azure) + CMB31-SRV01 (Arc)
Bicep ─▶ rg-contoso-dr-<ini>: vnet-contoso-dr-<ini> (10.70.0.0/16) + NSG
```

## Credenciais

`admin@<tenant>`.

---

## Exercício 1: Postura de segurança

### Tarefa 1: Defender for Cloud

1. Portal > **Microsoft Defender for Cloud > Getting started** (se for a primeira vez). Mantenha apenas o plano **Foundational CSPM** (gratuito). **Não active planos pagos** nesta tarefa.
1. **Overview:** anote o **Secure score**.
1. **Recommendations:** filtre por **Resource group** = `rg-contoso-*`. Procure recomendações como:
   - *Machines should have vulnerability findings resolved* / *Machines should be configured to periodically check for missing system updates*
   - *Storage accounts should restrict network access* (já tratado no LAB15?)
   - *Management ports should be closed on your virtual machines* (deve estar OK: não há RDP exposto)
1. **Regulatory compliance:** abra o **Microsoft cloud security benchmark** e veja os controlos que passam e falham.

### Tarefa 2: Corrigir uma recomendação

1. Escolha a recomendação ***Machines should be configured to periodically check for missing system updates***, se existir (será resolvida no Exercício 2). Caso contrário, escolha outra com **Fix** disponível e de baixo risco.
1. Abra-a, leia **Description**, **Remediation steps** e os recursos afectados. Anote para o Exercício 2.

> **Secure Score não é o objectivo, é o termómetro.** Cada recomendação tem um peso; o objectivo é perceber o **risco** que cada uma representa para a CONTOSO e decidir: corrigir, isentar (com justificação) ou aceitar.

### Tarefa 3: Azure Advisor

1. Portal > **Advisor > Recommendations**. Veja as categorias **Cost, Security, Reliability, Operational excellence, Performance**.
1. Em **Cost**, é comum aparecer uma sugestão para redimensionar ou desligar VMs pouco usadas. Em **Reliability**, a sugestão de usar **Availability Zones** ou **backup** (já tratado no LAB17).
1. Anote uma recomendação de cada categoria que a CONTOSO **aceitaria** e uma que **rejeitaria**, com justificação.

---

## Exercício 2: Actualizações

### Tarefa 4: Avaliar com o Azure Update Manager

1. Inicie a `vm-contoso-app01`.
1. Portal > **Azure Update Manager > Resources > Machines**. Devem aparecer a VM Azure e o `CMB31-SRV01` (Arc).
1. Seleccione a `vm-contoso-app01` > **Check for updates**. Aguarde (2-5 min).
1. Seleccione a `vm-contoso-app01` > **Update settings** > **Periodic assessment = Enable** > **Save**. (Isto resolve a recomendação da Tarefa 2.)

> **`Actualização 2026/2027`:** o antigo **Update Management** baseado em Automation Account e no agente MMA foi **descontinuado**. O **Azure Update Manager** é o serviço actual: não precisa de Automation Account nem de Log Analytics, e gere VMs Azure e servidores Arc no mesmo sítio.

> **Custo do Arc:** o Update Manager é **gratuito para VMs Azure**. Para servidores **Arc**, tem um custo mensal por servidor (salvo excepções, como servidores com benefícios de licenciamento específicos). Neste lab fazemos apenas a **avaliação** do SRV01, que não é cobrada como gestão contínua; não configure agendamentos no SRV01.

### Tarefa 5: Instalar actualizações críticas e de segurança

1. `vm-contoso-app01` > **One-time update** (ou **Install now**):
   - **Update classifications:** Critical, Security.
   - **Reboot option:** *Reboot if required*.
   - **Maintenance window:** 60 min.
1. Acompanhe em **History**.
1. **Opcional:** faça **Check for updates** (avaliação) no `CMB31-SRV01` e compare o estado de um servidor on-premises com o da VM no Azure, na mesma consola.

---

## Exercício 3: Automação

### Tarefa 6: Azure PowerShell vs Azure CLI

Faça a **mesma** tarefa nas duas ferramentas: listar os recursos da CONTOSO com a tag `CentroCusto=TI`, e parar a VM.

1. **Azure PowerShell** (Cloud Shell em PowerShell):

   ```powershell
   Get-AzResource -TagName CentroCusto -TagValue TI | Select-Object Name, ResourceType, ResourceGroupName | Sort-Object ResourceGroupName
   Get-AzVM -ResourceGroupName "rg-contoso-app-$ini" -Status | Select-Object Name, PowerState
   ```

1. **Azure CLI** (mude o Cloud Shell para **Bash**, ou escreva `bash`):

   ```bash
   INI=osm            # as suas iniciais
   LOC=northeurope    # região do curso
   az resource list --tag CentroCusto=TI --query "[].{nome:name, tipo:type, rg:resourceGroup}" -o table
   az vm list -g rg-contoso-app-$INI -d --query "[].{vm:name, estado:powerState}" -o table
   az vm deallocate -g rg-contoso-app-$INI -n vm-contoso-app01 --no-wait
   ```

> **Qual usar?** Ambas fazem o mesmo. PowerShell devolve **objectos** (natural para quem já administra Windows Server, como nos Domingos 1 e 2). CLI devolve **JSON/texto** e é comum em Linux e pipelines. A CONTOSO escolhe uma como padrão, mas a equipa deve saber ler as duas.

### Tarefa 7: Infraestrutura como código com Bicep

A direcção quer uma **rede de recuperação** pronta numa segunda região/RG, criada **sempre da mesma forma**.

1. No Cloud Shell (Bash), carregue o ficheiro: **Manage files > Upload** > `main.bicep` (de `Allfiles/Labs/18`). Leia-o com `cat main.bicep` e identifique: parâmetros, variável `tags`, NSG, VNet e a propriedade `defaultOutboundAccess: false` (subnet privada explícita, LAB14).
1. Crie o RG e faça uma **simulação** antes do deploy:

   ```bash
   az group create -n rg-contoso-dr-$INI -l $LOC --tags Projecto=COMBO Ambiente=Lab Dono=$INI CentroCusto=TI
   az deployment group what-if -g rg-contoso-dr-$INI -f main.bicep -p iniciais=$INI
   ```

   O `what-if` mostra o que **seria** criado (`+ Create`), sem criar nada.

1. Faça o deploy:

   ```bash
   az deployment group create -g rg-contoso-dr-$INI -f main.bicep -p iniciais=$INI -o table
   ```

1. Execute o **mesmo** comando outra vez. Termina rapidamente e não muda nada: o deploy é **idempotente** (descreve o estado desejado, não os passos).
1. Altere o ficheiro: no NSG, mude a porta `80` para `443` (`nano main.bicep`, Ctrl+O, Enter, Ctrl+X). Corra o `what-if` de novo: aparece **`~ Modify`** só nessa regra. Faça o deploy.

> Em produção, este ficheiro vive num **repositório Git** (como este), cada alteração passa por revisão (Pull Request) e o deploy é feito por um pipeline. A infraestrutura passa a ter **histórico, revisão e repetibilidade**.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB18`:

1. Captura do Secure Score e da recomendação analisada.
1. Tabela com as recomendações do Advisor aceites/rejeitadas e justificação.
1. Captura do **Update Manager** com a VM Azure e o SRV01 (Arc) e o histórico da instalação.
1. Saída dos comandos PowerShell e CLI equivalentes.
1. Saída do `what-if` antes do deploy e após a alteração da porta.

## Validação

- [ ] Secure Score consultado e pelo menos uma recomendação tratada.
- [ ] Recomendações do Advisor analisadas.
- [ ] Periodic assessment activo na VM; actualizações críticas/segurança instaladas.
- [ ] Mesma tarefa feita em PowerShell e CLI.
- [ ] Rede de DR criada com Bicep e alteração validada com `what-if`.

## Troubleshooting

| Sintoma | Solução |
|---|---|
| Defender for Cloud sem recomendações | A avaliação inicial demora até 24h numa subscription nova. Volte mais tarde. |
| Update Manager: *Check for updates* falha | VM parada ou sem saída para a Internet (NAT Gateway, LAB14). |
| `az deployment`: *RequestDisallowedByPolicy* | Região ou tags (LAB13). O ficheiro Bicep inclui as tags; confirme a região do RG. |
| `az deployment`: erro em `cidrSubnet` | Versão antiga do Bicep. `az bicep upgrade` e repita. |
| Cloud Shell em Bash não tem `$ini` | As variáveis PowerShell não passam para Bash; defina `INI=...`. |

## Challenge

1. Active o plano **Defender for Servers Plan 1** na subscription (tem período de avaliação gratuito; **verifique as condições actuais antes**), confirme que a `vm-contoso-app01` e o `CMB31-SRV01` (Arc) ficam cobertos e que aparecem no portal `security.microsoft.com` do LAB11. **Desactive o plano no fim.**
1. Escreva um ficheiro Bicep `storage.bicep` que crie uma storage account com as definições de segurança do LAB15 (HTTPS, TLS 1.2, sem acesso anónimo) e as tags da CONTOSO.

## Cleanup

**Fim dos labs Azure.** Antes de sair:

1. Elimine o RG de DR: `az group delete -n rg-contoso-dr-$INI --yes --no-wait`.
1. Se activou Defender for Servers no Challenge, **desactive-o**.
1. Execute o **Cleanup do [LAB17](LAB_17_Azure_Backup.md)** (vault).
1. Elimine o **NAT Gateway** e o seu IP público (custo por hora):

   ```powershell
   $app = Get-AzVirtualNetwork -Name "vnet-contoso-app-$ini" -ResourceGroupName "rg-contoso-net-$ini"
   ($app.Subnets | Where-Object Name -eq 'snet-app').NatGateway = $null
   $app | Set-AzVirtualNetwork
   Remove-AzNatGateway -Name "natgw-contoso-$ini" -ResourceGroupName "rg-contoso-net-$ini" -Force
   Remove-AzPublicIpAddress -Name "pip-natgw-contoso-$ini" -ResourceGroupName "rg-contoso-net-$ini" -Force
   ```

1. **Se ainda vai fazer o Capstone**, mantenha o resto com a VM **parada**. Caso contrário, siga a **limpeza total** do [Guia de Custos](../Guias/03_Custos_e_Limpeza.md) (lembre-se de retirar primeiro o Lock do `rg-contoso-net-<ini>`).
1. Para desligar o SRV01 do Arc quando terminar o curso: no SRV01, `azcmagent disconnect` e, no portal, elimine a máquina Arc.

## Resultado esperado

A CONTOSO consegue responder à auditoria: mede a sua postura de segurança, mantém os servidores actualizados nos dois mundos e recria infraestrutura a partir de código. **Fim dos laboratórios.** Agora, o Capstone.

**Próximo:** [CAPSTONE - CONTOSO Modernization Project](LAB_99_CAPSTONE_Contoso_Modernization.md)
