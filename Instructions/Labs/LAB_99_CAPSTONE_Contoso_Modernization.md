---
lab:
    title: 'CAPSTONE - CONTOSO Modernization Project'
    module: 'Domingo 6 - Projecto final'
---

# CAPSTONE - CONTOSO Modernization Project

| Código | Tecnologias | Duração | Peso na nota final |
|---|---|---|---|
| CAPSTONE | Windows Server + Microsoft 365 + Azure | 3h a 4h (+ apresentação de 10 min) | **40%** |

> **Este lab não tem passo a passo.** Recebe um cenário, requisitos e restrições, tal como num projecto real de consultoria. Decide **como** cumprir cada requisito, executa no seu ambiente e **prova** com evidências.

## O cenário

### Business case

Seis semanas depois do início da modernização, a CONTOSO Angola **adquiriu uma pequena empresa de logística, a KAMBA Transportes**, com escritório em **Benguela** e **12 colaboradores**. A direcção quer integrar a KAMBA **em 30 dias**, sem comprar servidores para Benguela.

A Directora Geral resumiu o pedido numa reunião:

> *"Os 12 colaboradores da KAMBA têm de entrar na segunda-feira com conta da CONTOSO, e-mail e acesso aos ficheiros de Vendas. Trabalham sobretudo na estrada, com portáteis. A KAMBA tem uma aplicação de rastreio de camiões num servidor velho que tem de ir para a cloud. E quero, numa página, o estado de segurança e os custos."*

### O que já existe (o seu ambiente dos LAB01-LAB18)

- Domínio `corp.contoso.com`, sincronizado com o Microsoft Entra ID.
- Microsoft 365 Business Premium (piloto TI/Financeiro/RH), Intune, Defender, Purview.
- Subscription Azure governada, com VNets hub/app, VM da aplicação, storage, monitorização e backup.

## Requisitos

### Windows Server (25%)

| ID | Requisito |
|---|---|
| WS-1 | Os 12 colaboradores da KAMBA existem no AD numa estrutura que permita aplicar-lhes **políticas diferentes** das da CONTOSO e **delegar** a sua gestão a um administrador local da KAMBA (`kamba.admin`), que só pode repor palavras-passe e desbloquear contas **da KAMBA**. |
| WS-2 | A KAMBA tem um grupo próprio com **acesso de leitura e escrita** a uma nova pasta `Logistica` no File Server e **só leitura** à pasta Vendas, seguindo o modelo AGDLP. |
| WS-3 | Os utilizadores da KAMBA têm a unidade `L:` mapeada automaticamente para `Logistica`. |
| WS-4 | Existe um backup testado (com restauro) da pasta `Logistica`. |

### Microsoft 365 (25%)

| ID | Requisito |
|---|---|
| M365-1 | Os utilizadores da KAMBA aparecem no Entra ID **sem criar contas manualmente na cloud**. |
| M365-2 | Pelo menos **3** utilizadores da KAMBA (motoristas-chefe) têm licença Business Premium **atribuída por grupo**. |
| M365-3 | Os utilizadores da KAMBA **exigem MFA sempre**, em qualquer local (trabalham na estrada). |
| M365-4 | Os portáteis da KAMBA são geridos pelo Intune, cifrados e só acedem ao e-mail se estiverem em conformidade. *(Use a CL02 ou uma nova VM para demonstrar um portátil.)* |
| M365-5 | Documentos com a palavra **"Rota Confidencial"** ou com números de cartão não podem sair da organização por e-mail. |

### Azure (25%)

| ID | Requisito |
|---|---|
| AZ-1 | A aplicação de rastreio da KAMBA corre numa **VM nova** no Azure, numa **subnet própria** (`snet-kamba`) **sem sobreposição** com nenhuma rede existente, sem IP público e administrável apenas via Bastion. |
| AZ-2 | A VM da KAMBA só aceita HTTP vindo da subnet da aplicação da CONTOSO e RDP via Bastion. Todo o resto vindo de outras redes internas é negado. |
| AZ-3 | Todos os recursos novos cumprem as **policies** do LAB13 (região, tags, convenção de nomes) **sem desactivar nenhuma policy**. |
| AZ-4 | A VM da KAMBA está **monitorizada** (alerta de CPU e de heartbeat para a equipa de TI) e tem **backup diário**. |
| AZ-5 | Pelo menos **um** recurso novo é criado a partir de **Bicep**. |

### Segurança (15%)

| ID | Requisito |
|---|---|
| SEC-1 | Nenhum administrador da KAMBA é Global Administrator. A conta `kamba.admin` tem apenas os papéis estritamente necessários, on-premises e na cloud. |
| SEC-2 | O Secure Score (Microsoft 365 **ou** Defender for Cloud) é apresentado com **duas** recomendações tratadas e justificadas. |
| SEC-3 | Existe um plano escrito de **resposta a um portátil roubado** da KAMBA (o que fazer na primeira hora, com as ferramentas do curso). |

### Documentação e apresentação (10%)

| ID | Requisito |
|---|---|
| DOC-1 | Documento de arquitectura (modelo em `Allfiles/Labs/99/Modelo_Documento_Arquitectura.md`), com diagrama, decisões e justificações. |
| DOC-2 | Apresentação de **10 minutos** ao "Director de TI" (instrutor): problema, solução, demonstração ao vivo de 2 requisitos à escolha do instrutor, custos e riscos. |

## Restrições

1. **Orçamento Azure:** os recursos novos não podem custar mais de **USD 5** durante o projecto. Justifique as escolhas de tamanho e as paragens.
1. **Não desactive** nenhuma policy, política de Conditional Access nem regra de segurança dos labs anteriores para "facilitar". Se um requisito colidir com uma regra existente, **explique a colisão e a solução**.
1. **Dados fictícios apenas.** Crie os 12 colaboradores da KAMBA com nomes fictícios (pode adaptar o CSV do LAB03).
1. Trabalho **individual**. Pode consultar os labs, a documentação Microsoft e o repositório.

## Entregáveis

Crie a pasta `Evidencias\CAPSTONE` com:

| Ficheiro | Conteúdo |
|---|---|
| `01_Arquitectura.md` (ou .docx/.pdf) | Documento de arquitectura (DOC-1) |
| `02_Evidencias.md` | Uma secção por requisito, com captura/saída de comando que o prove (modelo em `Allfiles/Labs/99/Checklist_Evidencias.md`) |
| `03_Plano_Portatil_Roubado.md` | SEC-3 |
| `04_IaC/` | Ficheiros Bicep usados (AZ-5) |
| `05_Apresentacao.pptx` (ou .pdf) | Máximo 8 diapositivos |

## Rubrica de avaliação

| Área | Peso | Excelente (100%) | Satisfatório (60%) | Insuficiente (0-30%) |
|---|---|---|---|---|
| Windows Server | 25% | WS-1 a WS-4 cumpridos e provados; delegação testada com a conta `kamba.admin` | 3 de 4 cumpridos, ou provas incompletas | 2 ou menos |
| Microsoft 365 | 25% | M365-1 a M365-5 cumpridos e provados; CA testada com What If e sign-in logs | 3-4 cumpridos | 2 ou menos |
| Azure | 25% | AZ-1 a AZ-5 cumpridos; policies intactas; custo dentro do orçamento | 3-4 cumpridos ou policy contornada sem justificação | 2 ou menos |
| Segurança | 15% | Privilégio mínimo demonstrado; plano de incidente concreto e exequível | Plano genérico ou privilégios excessivos num ponto | Contas com privilégios excessivos; sem plano |
| Documentação / Explicação | 10% | Decisões justificadas; demonstração fluida; responde a perguntas técnicas | Documento completo mas pouco justificado | Documento incompleto ou sem demonstração |

**Aprovação no Capstone:** 60% ou mais. **Nota final do curso:** Labs 40% + Checkpoints 20% + Capstone 40%.

## Pistas (leia só se ficar bloqueado(a) mais de 30 minutos)

<details>
<summary>WS-1 - estrutura e delegação</summary>

Uma OU `_CONTOSO\Utilizadores\KAMBA` permite GPOs próprias e delegação **com scope**. Reveja o LAB03, Tarefa 9, e aplique o assistente **Delegate Control** apenas nessa OU. A `kamba.admin` **não** deve ficar dentro da OU que gere.
</details>

<details>
<summary>M365-1 - utilizadores na cloud</summary>

Se criou a OU KAMBA **dentro** de `_CONTOSO\Utilizadores`, ela já está no filtro do Entra Connect (LAB08). Se a criou noutro lado, tem de rever o filtro.
</details>

<details>
<summary>M365-3 - MFA sempre</summary>

A CA003 só exige MFA fora do escritório e só para o piloto. Uma política nova, só para o grupo da KAMBA, sem condição de localização, resolve. Não se esqueça da exclusão da break-glass.
</details>

<details>
<summary>AZ-3 - policies e serviços automáticos</summary>

Reveja o "Ponto de atenção" do LAB13 e a Tarefa 3 do LAB17.
</details>

<details>
<summary>Orçamento</summary>

Um `Standard_B1s`/`B2ats_v2` com auto-shutdown, parado quando não está a ser demonstrado, custa cêntimos por dia. A VM da aplicação da CONTOSO pode ficar parada enquanto trabalha na da KAMBA.
</details>

## Cleanup (depois da avaliação)

Siga a **limpeza total** do [Guia de Custos](../Guias/03_Custos_e_Limpeza.md): Lock, vault, NAT Gateway, RGs `rg-contoso-*`, desligar o Arc. No Microsoft 365, cancele o trial quando já não precisar dele.

## Resultado esperado

Prova, sem guião, que consegue desenhar e entregar um ambiente Microsoft moderno de ponta a ponta: **do datacenter à cloud**. Parabéns: concluiu o COMBO PRO 3 em 1.
