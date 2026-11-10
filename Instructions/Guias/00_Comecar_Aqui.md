---
title: '00 - Começar aqui (Guia do Aluno auto-guiado)'
---

# Começar aqui - Guia do Aluno auto-guiado

Este guia explica como fazer o COMBO PRO 3 em 1 **ao seu ritmo**, dentro ou fora da sala.

## 1. Como funciona a jornada

- São **18 laboratórios + 1 Capstone**, em **sequência obrigatória**. Cada lab usa o que o anterior construiu.
- Em sala, fazem-se **3 labs por domingo** (6 domingos, 09h00-16h00).
- Em casa, conte com **1h30 a 2h por lab**. Um lab por noite é um bom ritmo.
- Cada lab começa com **"O problema"**: leia-o com atenção. O objectivo não é seguir passos; é **resolver o problema da CONTOSO**.

## 2. O que precisa

| Recurso | Para que serve | Como obter |
|---|---|---|
| Portátil com **16 GB RAM** (32 GB ideal), CPU com virtualização, **150 GB livres em SSD** | Correr as VMs Windows Server (LAB00 a LAB06, LAB08, LAB16) | Seu |
| **Windows 11 Pro/Enterprise** com Hyper-V | Hypervisor | Ver LAB00. Alternativa: VMware Workstation |
| ISO **Windows Server 2025** (Evaluation, 180 dias) | Servidores | Microsoft Evaluation Center |
| ISO **Windows 11 Enterprise** (Evaluation, 90 dias) | Clientes | Microsoft Evaluation Center |
| **Tenant Microsoft 365 Business Premium** (trial) | LAB07 a LAB12 | Ver LAB07. A academia tem tenants de reserva |
| **Subscription Azure** | LAB13 a LAB18 | Conta Azure gratuita ou subscription da academia (1 Resource Group por aluno) |
| Telemóvel com **Microsoft Authenticator** | MFA (LAB09) | Loja de aplicações |

> **Sem portátil potente?** Fale com a academia: existe a opção de usar as máquinas da sala ou um ambiente preparado.

## 3. Regras dos laboratórios

1. **Faça os labs pela ordem.** Não salte. Se um lab falhar, resolva-o antes de avançar.
2. **Crie um checkpoint antes de cada lab** (LAB00 explica como). Se algo correr mal, volta atrás em segundos.
3. **Guarde a evidência** de cada lab (captura de ecrã ou saída do PowerShell) numa pasta `Evidencias\LABxx`. O instrutor pede-as nos checkpoints e no Capstone.
4. **Use apenas dados fictícios.** Nunca use dados reais da sua empresa nos labs.
5. **No Azure, faça sempre o Cleanup** no fim do lab, salvo indicação em contrário. Recursos esquecidos custam dinheiro. Leia o [Guia de Custos](03_Custos_e_Limpeza.md).
6. **Tente o Challenge** de cada lab. É o que separa quem seguiu passos de quem percebeu.

## 4. Como ler um laboratório

| Secção | O que significa |
|---|---|
| **O problema** | A situação real da CONTOSO. É a razão de ser do lab. |
| **O que este lab resolve** | O resultado concreto que vai existir no fim. |
| **Pré-requisitos** | Labs que têm de estar concluídos. |
| **Topologia** | Que máquinas e serviços são usados. |
| **Exercícios e tarefas** | Passo a passo. Os blocos de código podem ser copiados. |
| **Evidência de conclusão** | O que deve guardar para provar que concluiu. |
| **Validação** | Lista de verificação. Se falhar um ponto, o lab não está concluído. |
| **Troubleshooting** | Os erros mais comuns e como os resolver. |
| **Challenge** | Tarefa extra, sem passo a passo. |
| **Cleanup** | O que desligar ou apagar. |

Convenções:

- Texto em **negrito** = nome de botão, menu ou campo.
- `Texto em código` = algo que escreve ou executa.
- `<SeuTenant>` ou `<iniciais>` = substitua pelo seu valor.
- **`Actualização 2026/2027`** = mudança recente da Microsoft em relação a materiais antigos.

## 5. Checkpoints e avaliação

| Componente | Peso |
|---|---|
| Labs concluídos (com evidência) | 40% |
| Checkpoints de fim de domingo | 20% |
| Capstone | 40% |

Certificado de conclusão: nota final igual ou superior a 60% e presença mínima de 5 domingos (alunos auto-guiados: todos os labs com evidência e Capstone aprovado).

## 6. Onde pedir ajuda

1. Secção **Troubleshooting** do próprio lab.
2. [Troubleshooting geral e FAQ](04_Troubleshooting_FAQ.md).
3. Grupo da turma (WhatsApp / Teams) - indique sempre **LAB, exercício, tarefa e passo**.
4. *Issue* neste repositório.

**Próximo passo:** leia o [Mapa da Jornada](01_Mapa_da_Jornada.md) e depois faça o [LAB00](../Labs/LAB_00_Preparar_o_Ambiente.md).
