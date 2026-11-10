---
lab:
    title: 'LAB16 - Azure Monitor + Azure Arc'
    module: 'Domingo 6 - Azure Operations'
---

# LAB16 - Azure Monitor + Azure Arc

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB16 | Log Analytics, Azure Monitor Agent, Data Collection Rules, Metrics, Alerts, Action Groups, KQL, Azure Arc | 120 min | 6 |

## O problema

Sexta-feira às 17h a VM da aplicação de encomendas ficou a 100% de CPU e deixou de responder. **Ninguém soube** até segunda-feira, quando os vendedores reclamaram que tinham perdido encomendas o fim-de-semana inteiro.

E há outro problema: a CONTOSO tem agora servidores **em dois sítios** (o File Server no escritório e a VM no Azure) e **duas formas diferentes** de os vigiar, ou seja, nenhuma.

*"Quero uma única consola onde vejo os servidores do escritório e da cloud, e quero ser avisado antes dos clientes."*

## O que este lab resolve

A CONTOSO passa a ter **monitorização centralizada**: um **Log Analytics workspace** que recebe eventos e desempenho **da VM no Azure e do File Server on-premises** (ligado através do **Azure Arc**), **alertas** de CPU alta e de servidor em baixo que **enviam e-mail** à equipa de TI, e consultas **KQL** para investigar.

## Objectivos

- Criar um Log Analytics workspace.
- Instalar o Azure Monitor Agent através de uma Data Collection Rule.
- Usar Metrics Explorer.
- Criar um Action Group, um alerta de métrica e um alerta de logs.
- Ligar um servidor on-premises ao Azure com **Azure Arc** e recolher os seus dados no mesmo workspace.
- Escrever consultas KQL simples.

## Pré-requisitos

- [LAB14](LAB_14_VNet_e_VM.md) concluído: `vm-contoso-app01` **com saída para a Internet** (NAT Gateway).
- [LAB05](LAB_05_File_Server_e_Permissoes.md): VMs **CMB31-DC01, CMB31-SRV01, CMB31-ADM01** ligadas para a parte Arc.
- Cloud Shell com `$ini`, `$loc`, `$tags`.

## Topologia

```text
                     law-contoso-<ini>  (rg-contoso-ops-<ini>, retenção 30 dias)
                      ▲                         ▲
       DCR: dcr-contoso-windows-<ini>           │
                      │                         │
   vm-contoso-app01 (Azure, AMA)       CMB31-SRV01 (on-premises, Arc + AMA)
                      │
   Alertas ──▶ ag-contoso-ti-<ini> (e-mail)
     ├── CPU > 80% durante 5 min (métrica)
     └── Sem heartbeat há 5 min (logs)
```

## Credenciais

`admin@<tenant>` | `azureadmin` (VM Azure) | `CONTOSO\Administrator` (on-premises).

---

## Exercício 1: Workspace e recolha de dados

### Tarefa 1: Log Analytics workspace

1. No Cloud Shell:

   ```powershell
   New-AzOperationalInsightsWorkspace -ResourceGroupName "rg-contoso-ops-$ini" -Name "law-contoso-$ini" `
       -Location $loc -Sku PerGB2018 -RetentionInDays 30 -Tag $tags
   ```

> **Custo:** paga-se por GB ingerido. Uma VM com eventos de erro e alguns contadores gera pouco. Retenção de 30 dias é incluída sem custo adicional.

### Tarefa 2: Data Collection Rule

1. Inicie a `vm-contoso-app01` (se estiver parada).
1. Portal > **Monitor > Settings > Data Collection Rules > + Create**:
   - Nome `dcr-contoso-windows-<ini>`, RG `rg-contoso-ops-<ini>`, região do curso, **Platform type: Windows**.
   - **Resources > + Add resources:** `vm-contoso-app01`. (Se pedir, permita a criação de **Data collection endpoint**: não é necessário neste lab.)
   - **Collect and deliver > + Add data source:**
     1. **Windows Event Logs:** *Basic* > **Application**: Critical, Error, Warning; **System**: Critical, Error, Warning. **Destination:** Azure Monitor Logs > `law-contoso-<ini>`.
     1. **Performance Counters:** *Basic* (CPU, memória, disco, rede), intervalo 60 s. **Destination:** `law-contoso-<ini>`.
   - **Tags:** as da CONTOSO. **Create**.
1. Na VM > **Settings > Extensions + applications**: aparece **AzureMonitorWindowsAgent** em *Provisioning succeeded* (pode demorar 5-10 min).

> **`Actualização 2026/2027`:** o antigo **Log Analytics agent (MMA/OMS)** foi **descontinuado** em Agosto de 2024. Materiais antigos que mandam "ligar a VM ao workspace" referem-se a ele. O caminho actual é o **Azure Monitor Agent (AMA)** configurado por **Data Collection Rules**: uma regra define **o quê** recolher e **para onde**, e aplica-se a muitas máquinas de uma vez.

### Tarefa 3: Confirmar a chegada de dados

1. Após 10-15 minutos: `law-contoso-<ini>` > **Logs** (feche a janela de consultas sugeridas e passe para **KQL mode**):

   ```kql
   Heartbeat
   | summarize UltimoSinal = max(TimeGenerated) by Computer, Category
   ```

   Deve ver `vm-contoso-app01` com **Category = Azure Monitor Agent**.

---

## Exercício 2: Métricas e alertas

### Tarefa 4: Metrics Explorer

1. `vm-contoso-app01` > **Monitoring > Metrics** > métrica **Percentage CPU**, agregação **Avg**, últimos 30 minutos.
1. **Pin to dashboard** > **Create new** > `CONTOSO - Operações`.

> As **métricas de plataforma** (CPU, rede, disco) existem **sem agente**: são recolhidas pelo hypervisor do Azure. Os **logs** e contadores do sistema operativo precisam do AMA.

### Tarefa 5: Action Group

1. **Monitor > Alerts > Action groups > + Create**:
   - RG `rg-contoso-ops-<ini>`, nome `ag-contoso-ti-<ini>`, display name `CONTOSO-TI`.
   - **Notifications:** *Email/SMS message/Push/Voice* > nome `email-ti` > **Email** = o seu.
   - **Create**. Receberá um e-mail a confirmar que foi adicionado ao grupo.

### Tarefa 6: Alerta de CPU (métrica)

1. `vm-contoso-app01` > **Monitoring > Alerts > + Create > Alert rule**:
   - **Signal:** Percentage CPU. **Threshold:** Static, **Greater than**, `80`. **Aggregation:** Average. **Check every** 1 min, **Lookback** 5 min.
   - **Actions:** `ag-contoso-ti-<ini>`.
   - **Details:** severidade **2 - Warning**, nome `alr-cpu-alta-app01`.
   - **Create**.

### Tarefa 7: Provocar o alerta

1. Ligue-se à VM via Bastion e, em PowerShell, gere carga durante ~8 minutos:

   ```powershell
   $fim = (Get-Date).AddMinutes(8)
   1..([Environment]::ProcessorCount) | ForEach-Object {
       Start-Job -ScriptBlock { param($f) while ((Get-Date) -lt $f) { [math]::Sqrt(12345) | Out-Null } } -ArgumentList $fim
   }
   ```

1. Observe a CPU no **Task Manager** e no **Metrics Explorer**.
1. Em 5-10 minutos, recebe um e-mail **Fired**. Depois de a carga terminar, recebe **Resolved**.
1. **Monitor > Alerts:** veja o histórico do alerta.

### Tarefa 8: "O servidor caiu e ninguém soube" (alerta de logs)

1. `law-contoso-<ini>` > **Alerts > + Create > Alert rule** > **Signal: Custom log search**:

   ```kql
   Heartbeat
   | summarize UltimoSinal = max(TimeGenerated) by Computer
   | where UltimoSinal < ago(5m)
   ```

   - **Measurement:** *Table rows*, **Aggregation granularity** 5 min.
   - **Alert logic:** *Greater than* `0`. **Frequency of evaluation:** 5 min.
   - **Actions:** `ag-contoso-ti-<ini>`. **Details:** severidade **1 - Error**, nome `alr-servidor-sem-heartbeat`.
1. **Pare** a `vm-contoso-app01` no portal. Em 10-15 minutos, recebe o e-mail.
1. Volte a **iniciar** a VM.

---

## Exercício 3: Trazer o on-premises para o Azure (Azure Arc)

### Tarefa 9: Gerar o script de onboarding

1. Portal > **Azure Arc > Machines > + Add/Create > Add a machine > Add a single server > Generate script**.
   - RG `rg-contoso-ops-<ini>`, região do curso, **Operating system:** Windows, **Connectivity method:** Public endpoint.
   - **Tags:** as da CONTOSO (adicione também `Local=Luanda-Talatona`).
   - **Download** o script `OnboardingScript.ps1`.

### Tarefa 10: Ligar o CMB31-SRV01

1. Copie o script para o **ADM01** (por exemplo para `C:\Labfiles\16`) e daí para o SRV01:

   ```powershell
   New-Item -ItemType Directory \\CMB31-SRV01\C$\Temp -Force | Out-Null
   Copy-Item C:\Labfiles\16\OnboardingScript.ps1 -Destination \\CMB31-SRV01\C$\Temp\ -Force
   Enter-PSSession CMB31-SRV01
   Set-ExecutionPolicy -Scope Process Bypass -Force
   C:\Temp\OnboardingScript.ps1
   ```

1. O script instala o **Azure Connected Machine agent** e mostra um **código de dispositivo**. No browser do ADM01 ou do portátil, abra `https://microsoft.com/devicelogin`, introduza o código e entre como `admin@<tenant>`.
1. No portal, **Azure Arc > Machines**: `CMB31-SRV01` aparece com **Status = Connected**. Um servidor **no seu portátil** é agora um recurso Azure, com tags, RBAC e Policy.

> **Porque funciona sem VPN?** O agente Arc faz **ligações de saída HTTPS** (porta 443) para o Azure. Não é preciso abrir portas de entrada no escritório.

### Tarefa 11: Recolher dados do servidor on-premises

1. Abra `dcr-contoso-windows-<ini>` > **Resources > + Add** > `CMB31-SRV01` (tipo *Machine - Azure Arc*). **Apply**.
1. A extensão AMA é instalada no SRV01 através do Arc (5-15 min).
1. No workspace:

   ```kql
   Heartbeat
   | summarize UltimoSinal = max(TimeGenerated) by Computer, ComputerEnvironment
   ```

   Agora vê **duas** máquinas: `vm-contoso-app01` (**Azure**) e `CMB31-SRV01` (**Non-Azure**). **Uma consola, dois sítios.**

### Tarefa 12: Investigar com KQL

1. Gere um evento de erro no SRV01 (a partir da sessão remota):

   ```powershell
   eventcreate /T ERROR /ID 900 /L APPLICATION /SO CONTOSO-LAB16 /D "Teste LAB16: falha simulada na aplicação de ficheiros"
   ```

1. Após alguns minutos, no workspace:

   ```kql
   Event
   | where TimeGenerated > ago(1h)
   | where EventLevelName == "Error"
   | project TimeGenerated, Computer, Source, EventID, RenderedDescription
   | order by TimeGenerated desc
   ```

1. E o desempenho comparado:

   ```kql
   Perf
   | where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"
   | summarize CPU_Media = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
   | render timechart
   ```

---

## Evidência de conclusão

Guarde em `Evidencias\LAB16`:

1. Resultado da consulta `Heartbeat` com as **duas** máquinas (Azure e Non-Azure).
1. E-mails **Fired** e **Resolved** do alerta de CPU.
1. E-mail do alerta de heartbeat.
1. Captura de `CMB31-SRV01` em **Azure Arc > Machines** com **Connected**.
1. Resultado da consulta `Event` com o evento 900.

## Validação

- [ ] Workspace com retenção de 30 dias.
- [ ] DCR a recolher eventos e desempenho da VM Azure **e** do servidor Arc.
- [ ] Action group a enviar e-mail.
- [ ] Alerta de CPU disparou e resolveu.
- [ ] Alerta de servidor sem heartbeat disparou.
- [ ] SRV01 ligado ao Azure Arc.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| Sem `Heartbeat` da VM Azure | VM sem saída para a Internet | Confirme o NAT Gateway (LAB14). Veja o estado da extensão AMA. |
| Extensão AMA em *Failed* | Falta identidade gerida | VM > **Identity > System assigned = On** e reaplique a DCR. |
| Alerta de CPU não dispara | Carga insuficiente ou curta | Mantenha a carga > 5 min; confirme no Metrics Explorer que passou de 80%. |
| Script Arc falha: *policy disallowed* | Tag ou região bloqueada pela policy do LAB13 | Use a região permitida e inclua a tag `CentroCusto` ao gerar o script. |
| Arc: falha de ligação | SRV01 sem Internet | No SRV01: `Test-NetConnection management.azure.com -Port 443`. Confirme DNS/forwarders (LAB02) e NAT do portátil. |
| Alertas não chegam por e-mail | Confirmação do action group | Verifique spam; teste com **Action group > Test action group**. |

## Challenge

1. Crie um **workbook** (Monitor > Workbooks > Empty) com duas tabelas: últimos erros de eventos por computador e CPU média por computador nas últimas 24h. Guarde-o como `CONTOSO - Saúde dos Servidores`.
1. Adicione o **CMB31-DC01** ao Arc e à DCR, e escreva uma consulta que mostre **quantos erros** cada um dos três servidores registou na última hora.

## Cleanup

1. **Mantenha** o workspace, a DCR e os servidores Arc (usados no LAB18).
1. **Desactive** a regra `alr-servidor-sem-heartbeat` (a VM vai estar parada fora das aulas e geraria alertas constantes): **Monitor > Alerts > Alert rules > Disable**.
1. Pare a `vm-contoso-app01` se não continuar.

## Resultado esperado

A CONTOSO vê numa única consola os servidores do escritório e da cloud, e a equipa de TI sabe que algo está mal **antes** dos clientes.

**Próximo lab:** [LAB17 - Azure Backup](LAB_17_Azure_Backup.md)
