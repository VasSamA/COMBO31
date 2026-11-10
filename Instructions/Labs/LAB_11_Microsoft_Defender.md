---
lab:
    title: 'LAB11 - Microsoft Defender XDR'
    module: 'Domingo 4 - Microsoft 365 Security & Compliance'
---

# LAB11 - Microsoft Defender XDR

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB11 | Microsoft Defender for Business (Endpoint), Defender for Office 365 P1, Defender XDR, Secure Score | 105 min | 4 |

## O problema

A CONTOSO recebe dezenas de e-mails de phishing por semana, alguns com anexos "factura.pdf.exe". Ninguém sabe **quantos** chegaram, **quem** clicou, nem se algum portátil foi infectado. O antivírus de cada PC funciona sozinho e ninguém olha para os alertas.

*"Se formos atacados, quero saber em minutos, não quando os clientes ligarem a dizer que receberam e-mails estranhos nossos."*

## O que este lab resolve

A CONTOSO passa a ter uma **consola única de segurança** (`security.microsoft.com`) onde se vêem **dispositivos, e-mail e identidades**. O portátil do Financeiro fica **protegido e visível no Defender**, com antivírus reforçado e regras de redução da superfície de ataque. O e-mail recebe as **políticas de protecção pré-definidas** (Safe Links, Safe Attachments, anti-phishing). A equipa pratica a **resposta a um incidente**: ver o alerta, investigar e isolar o dispositivo. E passa a medir a postura de segurança com o **Secure Score**.

## Objectivos

- Ligar o Intune ao Defender e inscrever (onboard) a CL02.
- Configurar antivírus e regras ASR por Endpoint security.
- Gerar um alerta de teste e investigar o incidente.
- Isolar e libertar um dispositivo.
- Aplicar as preset security policies do Defender for Office 365.
- Implementar uma acção do Secure Score.

## Pré-requisitos

- [LAB10](LAB_10_Microsoft_Intune.md) concluído (CL02 gerida pelo Intune).
- VMs a ligar: **CMB31-DC01, CMB31-CL02**.

## Topologia

```text
                 Microsoft Defender portal (security.microsoft.com)
                ┌──────────────┬────────────────────┬─────────────────┐
                │ Endpoints    │ E-mail & colaboração│ Identidades     │
                │ (Defender for│ (Defender for Office│ (sign-ins Entra)│
                │  Business)   │  365 Plan 1)        │                 │
                └──────┬───────┴─────────┬───────────┴─────────────────┘
                       │                 │
              CMB31-CL02 (Intune)    Exchange Online (caixas da CONTOSO)
```

> **Licenciamento:** o Business Premium inclui **Defender for Business** (equivalente ao Defender for Endpoint para PME) e **Defender for Office 365 Plan 1**. Funcionalidades como **Threat Explorer**, **Attack simulation training** e **Automated investigation para e-mail** exigem o **Plan 2** (incluído no E5).

## Credenciais

`admin@<tenant>` | `helena.matos@<tenant>` (sessão na CL02).

---

## Exercício 1: Proteger o endpoint

### Tarefa 1: Ligar o Defender ao Intune

1. Abra `https://security.microsoft.com` como `admin@<tenant>`. Na primeira visita, pode aparecer o **assistente de configuração do Defender for Business**. Se aparecer, escolha inscrever dispositivos **através do Microsoft Intune** e conclua. Se não aparecer, continue:
1. **System > Settings > Endpoints > Advanced features:** **Microsoft Intune connection = On**. **Save preferences**.
1. Em `https://intune.microsoft.com` > **Endpoint security > Microsoft Defender for Endpoint:** **Connect Windows devices version 10.0.15063 and above to Microsoft Defender for Endpoint = On**. **Save**.

### Tarefa 2: Inscrever a CL02 (onboarding)

1. Intune > **Endpoint security > Endpoint detection and response > Create policy** > **Windows** > **Endpoint detection and response**.
1. Nome `EDR-Onboarding-CONTOSO`. *Microsoft Defender for Endpoint client configuration package type* = **Auto from connector**.
1. **Assignments:** `DEV-Windows-Corporativos`. **Create**.
1. Sincronize a CL02. Após 15-30 min, a CL02 aparece em `security.microsoft.com` > **Assets > Devices** com **Onboarding status = Onboarded**.

### Tarefa 3: Antivírus e ASR

1. Intune > **Endpoint security > Antivirus > Create policy > Windows > Microsoft Defender Antivirus**. Nome `AV-CONTOSO`:
   - *Allow Cloud Protection* = Allowed; *Cloud Block Level* = **High**.
   - *PUA Protection* = **On**.
   - *Allow Realtime Monitoring* = Allowed.
   - Atribuir a `DEV-Windows-Corporativos`.
1. **Endpoint security > Attack surface reduction > Create policy > Windows > Attack Surface Reduction Rules**. Nome `ASR-CONTOSO-Auditoria`:
   - *Block all Office applications from creating child processes* = **Audit**.
   - *Block executable content from email client and webmail* = **Audit**.
   - *Block credential stealing from the Windows local security authority subsystem* = **Block**.
   - Atribuir a `DEV-Windows-Corporativos`.

> **Porquê Audit primeiro?** Regras ASR podem partir aplicações de negócio (ex.: uma macro do Financeiro). Começa-se em **Audit**, analisa-se o relatório durante 2-4 semanas e só depois se passa a **Block**.

---

## Exercício 2: Responder a um incidente

### Tarefa 4: Gerar um alerta de teste

1. Em `security.microsoft.com` > **System > Settings > Endpoints > Onboarding** > sistema operativo **Windows 10 and 11**. Na secção **Run a detection test**, copie o comando de teste fornecido pela Microsoft (é inofensivo: simula um comportamento suspeito para validar o onboarding).
1. Na **CL02**, abra uma **Linha de Comandos como administrador** (use `labadmin` se pedido) e cole o comando. A janela pode fechar sozinha.
1. Aguarde 5-15 minutos.

### Tarefa 5: Investigar

1. **Incidents & alerts > Incidents:** abra o incidente associado à CL02.
1. Explore os separadores: **Attack story**, **Alerts**, **Assets**, **Evidence and Response**.
1. Abra o dispositivo > **Timeline**: encontre o processo que gerou o alerta e a hora exacta.
1. No incidente: **Assign to me** > **Classification = Informational, expected activity** > **Determination = Security testing**.

### Tarefa 6: Isolar e libertar

1. No dispositivo CL02 > **... > Isolate device** > **Full** > comentário `Teste LAB11`.
1. Na CL02, tente abrir `https://www.microsoft.com`: **sem acesso**. O dispositivo só fala com o serviço Defender.
1. No portal: **Action center** confirma o isolamento.
1. **Release from isolation**. Confirme que a navegação volta (pode demorar alguns minutos).

> Isolar um portátil comprometido **impede a propagação** (movimento lateral) mantendo-o investigável remotamente. É das acções mais valiosas na primeira hora de um incidente.

---

## Exercício 3: Proteger o e-mail

### Tarefa 7: Preset security policies

1. `security.microsoft.com` > **Email & collaboration > Policies & rules > Threat policies > Preset security policies**.
1. **Standard protection > Manage protection settings**:
   - **Exchange Online Protection:** All recipients.
   - **Defender for Office 365 protection:** All recipients.
   - **Impersonation protection:** adicione `Helena Matos` e `Paulo Kiala` como utilizadores a proteger contra imitação, e o domínio do tenant.
   - **Confirm**.
1. Abra **Threat policies > Configuration analyzer** e compare as suas políticas com o perfil **Standard**.

> As preset policies aplicam **Safe Links**, **Safe Attachments**, anti-phishing, anti-spam e anti-malware com valores recomendados pela Microsoft, e **actualizam-se sozinhas** quando a Microsoft muda as recomendações.

### Tarefa 8: Quarentena e relatórios

1. **Email & collaboration > Review > Quarantine:** observe (pode estar vazia num tenant novo).
1. **Reports > Email & collaboration > Threat protection status:** veja o gráfico (dados aparecem com o uso).
1. **Real-time detections** (Plan 1): procure e-mails das últimas 24h.

---

## Exercício 4: Secure Score

### Tarefa 9: Medir e melhorar

1. **Exposure management > Secure score** (ou **Secure score** no menu).
1. Anote a **pontuação actual**.
1. Separador **Recommended actions:** filtre por **Not addressed**. Escolha **uma** acção relacionada com o que já fez ou pode fazer agora. Exemplos frequentes:
   - *Ensure all users can complete multifactor authentication* (LAB09)
   - *Enable Microsoft Entra ID Identity Protection...* (exige P2: marque como **Risk accepted**, com justificação)
   - *Turn on Safe Attachments / Safe Links* (Tarefa 7)
1. Abra a acção, leia **Implementation**, implemente (se ainda não estiver) e altere o estado. As melhorias reflectem-se na pontuação em até 24-48h.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB11`:

1. Captura da CL02 em **Devices** com **Onboarded** e **Risk level**.
1. Captura do incidente com a classificação atribuída.
1. Captura do **Action center** com o isolamento e a libertação.
1. Captura das preset policies (Standard activa).
1. Captura do Secure Score com a acção tratada.

## Validação

- [ ] CL02 inscrita no Defender via Intune.
- [ ] Políticas de antivírus e ASR atribuídas.
- [ ] Incidente de teste investigado e classificado.
- [ ] Isolamento e libertação executados.
- [ ] Standard preset policy activa para todos os destinatários.
- [ ] Uma acção do Secure Score tratada.

## Troubleshooting

| Sintoma | Solução |
|---|---|
| CL02 não aparece em Devices | Confirme as ligações Intune <-> Defender (Tarefa 1) e a política EDR atribuída a um grupo onde a CL02 está. Pode levar até 1h na primeira vez. |
| O teste de detecção não gera alerta | Confirme **Onboarded** antes de correr o teste. Execute como administrador. |
| Não aparece a opção **Isolate device** | Dispositivo ainda não totalmente inscrito ou permissões insuficientes. Use `admin@<tenant>`. |
| Preset policies indisponíveis | Licenças Defender for Office 365 ainda a provisionar num tenant novo. Aguarde algumas horas. |

## Challenge

Escreva uma consulta **Advanced Hunting** (KQL) que liste os processos iniciados na CL02 nas últimas 24h pelo `cmd.exe`:

```kql
DeviceProcessEvents
| where Timestamp > ago(24h)
| where InitiatingProcessFileName =~ "cmd.exe"
| project Timestamp, DeviceName, FileName, ProcessCommandLine
| order by Timestamp desc
```

Encontre a linha do teste da Tarefa 4. (Advanced Hunting está disponível no Defender for Business com retenção limitada; se não estiver no seu tenant, use o **Timeline** do dispositivo.)

## Cleanup

Confirme que a CL02 **não ficou isolada**. Mantenha as políticas.

## Resultado esperado

A CONTOSO vê o que se passa nos seus portáteis e no seu e-mail numa única consola, sabe responder a um incidente em minutos e tem uma métrica objectiva (Secure Score) para mostrar à direcção.

**Próximo lab:** [LAB12 - Microsoft Purview](LAB_12_Microsoft_Purview.md)
