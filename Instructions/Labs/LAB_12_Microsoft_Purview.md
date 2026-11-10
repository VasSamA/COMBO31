---
lab:
    title: 'LAB12 - Microsoft Purview'
    module: 'Domingo 4 - Microsoft 365 Security & Compliance'
---

# LAB12 - Microsoft Purview

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB12 | Microsoft Purview: Sensitivity labels, DLP, Retention, Audit | 105 min | 4 |

## O problema

Três situações na CONTOSO no último mês:

1. Um vendedor enviou por e-mail a um cliente uma folha com **números de cartão de pagamento** de outros clientes.
1. O mapa salarial do RH foi reencaminhado "sem querer" para fora da empresa. Ninguém sabia que o documento era confidencial.
1. A Administração Geral Tributária pediu facturas de há 6 anos e alguém já as tinha apagado da caixa de correio.

E quando a direcção perguntou *"quem abriu o ficheiro dos salários?"*, ninguém soube responder.

## O que este lab resolve

A CONTOSO passa a **classificar** os documentos (Público, Geral, Confidencial) com marcas visíveis e cifra, a **impedir automaticamente** o envio de dados de cartões de pagamento para fora (DLP), a **reter** o correio do Financeiro durante o prazo legal e a **auditar** quem fez o quê.

## Objectivos

- Confirmar e usar a auditoria unificada.
- Criar e publicar sensitivity labels.
- Criar uma política DLP em modo de simulação e depois activa.
- Criar uma política de retenção.
- Pesquisar no audit log.

## Pré-requisitos

- [LAB08](LAB_08_Identidade_Hibrida.md) concluído (utilizadores licenciados). LAB10/LAB11 não são necessários.
- **Não precisa das VMs.** Use o browser.
- Utilizadores: `helena.matos`, `adilson.cassoma` (Financeiro, licenciados), `admin@<tenant>`.
- Um endereço de e-mail **externo** seu (Gmail, Outlook.com) para testar a DLP.

> **Atenção ao tempo:** a publicação de labels e políticas pode demorar **até 24 horas**. Faça os Exercícios 2-4 de seguida e valide os testes no fim do lab ou no dia seguinte.

## Topologia

```text
Microsoft Purview portal (purview.microsoft.com)
├── Audit                      -> quem fez o quê
├── Information Protection     -> Público | Geral | Confidencial
├── Data Loss Prevention       -> DLP-Cartoes-Pagamento (Exchange, SharePoint, OneDrive, Teams)
└── Data Lifecycle Management  -> RET-Email-Financeiro-7anos
```

## Credenciais

`admin@<tenant>` (Global Administrator, inclui Compliance Administrator) | `helena.matos`, `adilson.cassoma`.

---

## Exercício 1: Auditoria

### Tarefa 1: Confirmar que a auditoria está ligada

1. Abra `https://purview.microsoft.com` como `admin@<tenant>` > **Solutions > Audit**.
1. Se aparecer **Start recording user and admin activity**, seleccione-o. Em tenants novos já vem ligado.

> O Business Premium inclui **Audit (Standard)**: retenção de **180 dias**. Audit (Premium), com 1 ano e eventos de acesso a e-mail mais detalhados, exige E5.

---

## Exercício 2: Classificar a informação

### Tarefa 2: Criar as labels

1. **Solutions > Information Protection > Sensitivity labels > + Create a label**.
1. Label **Público**: *Scope* = **Files & other data assets** e **Emails**. Sem cifra, sem marcação. **Create**.
1. Label **Geral**: igual à anterior, com **Content marking > Add a footer** = `CONTOSO - Uso interno`.
1. Label **Confidencial**:
   - Scope: Files & Emails.
   - **Access control > Configure access control settings** > **Assign permissions now** > **Add all users and groups in your organization** com permissão **Co-Author**. *User access to content expires* = Never; *Allow offline access* = Always.
   - **Content marking:** **Header** `CONTOSO - CONFIDENCIAL` (vermelho) e **Watermark** `CONFIDENCIAL`.
   - **Create**.

> **Efeito da label Confidencial:** o ficheiro fica **cifrado**. Se for reencaminhado para fora, a pessoa externa **não o consegue abrir**, porque não pertence à organização. A protecção viaja **com o ficheiro**, não com a pasta.

### Tarefa 3: Publicar

1. **Publish labels** (ou **Label policies > Publish label**):
   - Labels: Público, Geral, Confidencial.
   - Users and groups: **All users and groups**.
   - **Default label for documents** = **Geral**; **Default label for emails** = **Geral**.
   - **Require users to provide justification to remove a label or lower its classification** = marcado.
   - Nome `LBL-Politica-CONTOSO`. **Submit**.

### Tarefa 4: Testar (pode exigir aguardar a propagação)

1. Numa janela privada, entre em `https://www.office.com` como `helena.matos` > **Word** > documento novo `Mapa_Salarial_2027.docx`.
1. Na barra, **Sensitivity** (ou botão de sensibilidade) > **Confidencial**. Veja o cabeçalho e a marca de água.
1. Tente baixar para **Geral**: é pedida justificação.

---

## Exercício 3: Data Loss Prevention

### Tarefa 5: Criar a política DLP

1. **Solutions > Data loss prevention > Policies > + Create policy** > **Data stored in connected sources** (ou **Enterprise applications & devices**) > **Custom > Custom policy**.
1. Nome `DLP-Cartoes-Pagamento`. Descrição: *Impede partilha externa de números de cartão de pagamento.*
1. **Admin units:** Full directory.
1. **Locations:** **Exchange email**, **SharePoint sites**, **OneDrive accounts**, **Teams chat and channel messages** (todos, All).
1. **Define policy settings > Create or customize advanced DLP rules > + Create rule**:
   - Nome `Cartao-Externo`.
   - **Conditions:** *Content contains > Sensitive info types > Credit Card Number* (instance count 1 to Any, **High confidence**) **AND** *Content is shared from Microsoft 365 > with people outside my organization*.
   - **Actions:** *Restrict access or encrypt the content in Microsoft 365 locations > Block only people outside your organization*.
   - **User notifications:** On, com **policy tip** personalizado: `Este conteúdo contém dados de cartões de pagamento e não pode ser enviado para fora da CONTOSO.`
   - **User overrides:** desligado.
   - **Incident reports:** severidade **High**, enviar alerta aos administradores.
1. **Policy mode:** **Run the policy in simulation mode** (*Show policy tips while in simulation mode* marcado). **Submit**.

> **Modo de simulação:** a política regista o que **teria** bloqueado, sem incomodar os utilizadores. Em produção, corre-se 1-2 semanas em simulação para afinar falsos positivos.

### Tarefa 6: Activar e testar

1. Depois de alguns minutos, edite a política e mude para **Turn it on immediately**.
1. Como `adilson.cassoma`, em `https://outlook.office.com`, envie um e-mail **para o seu e-mail pessoal externo** com o texto:

   ```text
   Segue o cartão de crédito Visa do cliente para o débito:
   Cartão de crédito: 4111 1111 1111 1111   Validade: 12/29
   ```

   > `4111 1111 1111 1111` é um **número de teste público** (não pertence a ninguém) que passa na validação de formato de cartões.

1. Resultado esperado: **policy tip** ao escrever e **mensagem bloqueada / devolvida (NDR)** ao enviar para fora.
1. Envie o mesmo texto para `helena.matos` (interno): é **entregue**. A regra só bloqueia o exterior.
1. **Data loss prevention > Alerts:** abra o alerta e veja o que foi detectado.

---

## Exercício 4: Retenção

### Tarefa 7: Reter o correio do Financeiro

1. **Solutions > Data Lifecycle Management > Microsoft 365 > Retention policies > + New retention policy**.
1. Nome `RET-Email-Financeiro-7anos`.
1. **Policy scope:** **Static**.
1. **Locations:** apenas **Exchange mailboxes** > **Edit** > **Include specific** > `Helena Matos`, `Adilson Cassoma` e restantes colaboradores do Financeiro licenciados.
1. **Retention settings:** *Retain items for a specific period* = **7 years**, *Start the retention period based on* = **When items were created**, *At the end of the retention period* = **Do nothing**.
1. **Submit**.

> **Retenção não é backup.** Uma política de retenção garante que o conteúdo **não é eliminado de forma permanente** durante o prazo (mesmo que o utilizador o apague, fica guardado em local oculto e pesquisável por eDiscovery). Protege contra eliminação, não contra corrupção ou ransomware.

### Tarefa 8: Verificar

1. Como `adilson.cassoma`, apague um e-mail e esvazie também **Itens Eliminados** e **Recuperar itens eliminados**.
1. Explique (sem executar) como o administrador encontraria esse e-mail: **Solutions > eDiscovery > Search**, pesquisando na caixa do Adilson. O item continua disponível graças à política de retenção. *(A política pode demorar até 7 dias a aplicar-se integralmente a caixas existentes; em laboratório, o objectivo é a configuração.)*

---

## Exercício 5: "Quem abriu o ficheiro dos salários?"

### Tarefa 9: Pesquisar no audit log

1. Como `helena.matos`, guarde o `Mapa_Salarial_2027.docx` no OneDrive e partilhe-o com `adilson.cassoma`. Como Adilson, abra-o.
1. Aguarde 30-60 minutos (latência normal da auditoria).
1. **Audit > New search:**
   - **Activities - friendly names:** *Accessed file*, *Shared file, folder, or site*.
   - **File, folder, or site:** `Mapa_Salarial`.
   - **Search**.
1. Abra os resultados: utilizador, hora, IP e operação. **Export** para CSV.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB12`:

1. Captura das 3 labels e da política de publicação.
1. Captura de um documento com a label **Confidencial** (cabeçalho e marca de água visíveis).
1. Captura do NDR / bloqueio da DLP e do alerta DLP.
1. Captura da política de retenção.
1. CSV ou captura da pesquisa de auditoria com o acesso do Adilson.

## Validação

- [ ] Auditoria ligada.
- [ ] Labels Público, Geral e Confidencial publicadas; Geral por omissão.
- [ ] DLP bloqueia cartões de pagamento para fora e permite internamente.
- [ ] Retenção de 7 anos no correio do Financeiro.
- [ ] Sabe responder a "quem abriu o ficheiro" com o audit log.

## Troubleshooting

| Sintoma | Solução |
|---|---|
| Labels não aparecem no Office | Propagação até 24h. Feche e reabra o Office na web, ou tente noutra janela privada no dia seguinte. |
| DLP não bloqueia | Política ainda em simulação, ou propagação (até 1h). Confirme que o texto inclui palavras-chave e validade (aumentam a confiança da detecção). |
| Audit sem resultados | Latência de 30 min a algumas horas. Confirme o intervalo de datas da pesquisa. |
| Não consigo criar labels com cifra | O serviço de protecção (Azure Rights Management) é activado automaticamente em tenants novos; se aparecer erro, aguarde e tente de novo. |

## Challenge

Crie uma **label automática recomendada** (*auto-labeling* no cliente): quando um documento Word contiver números de cartão de pagamento, o Office **recomenda** aplicar **Confidencial**. Teste com o número de teste. *(Auto-labeling do lado do serviço, que classifica ficheiros já guardados, exige E5.)*

## Cleanup

Mantenha as labels e a retenção. Se o e-mail de teste ficou na sua caixa pessoal, apague-o.

## Resultado esperado

A informação da CONTOSO tem classificação, protecção que viaja com o ficheiro, regras que impedem fugas de dados, retenção legal e um registo de quem fez o quê. **Fim do Microsoft 365.** No Domingo 5 a CONTOSO entra no Azure.

**Próximo lab:** [LAB13 - Azure Governance](LAB_13_Azure_Governance.md)
