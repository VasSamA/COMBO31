# COMBO PRO 3 em 1 - Windows Server + Microsoft 365 + Microsoft Azure

**VASSAMA Academy | Laboratórios auto-guiados**

> *"Do Datacenter à Cloud"* - começa com um servidor vazio e termina a administrar um ambiente Microsoft moderno, híbrido e seguro.

Este repositório contém **todos os laboratórios do COMBO PRO 3 em 1**, organizados como **uma única jornada**. Cada laboratório parte de um **problema real da empresa fictícia CONTOSO** e resolve-o com prática. Os labs foram escritos para serem feitos **em sala ou em casa, sem instrutor**.

- **[Abrir a versão web dos labs](https://vassama.github.io/COMBO31/)** (GitHub Pages)
- **[Começar aqui: Guia do Aluno auto-guiado](Instructions/Guias/00_Comecar_Aqui.md)**
- **[Mapa da jornada e dependências entre labs](Instructions/Guias/01_Mapa_da_Jornada.md)**
- **[Ambiente de laboratório (VMs, IPs, credenciais)](Instructions/Guias/02_Ambiente_de_Laboratorio.md)**
- **[Custos e como não gastar dinheiro por engano](Instructions/Guias/03_Custos_e_Limpeza.md)**
- **[Troubleshooting geral e FAQ](Instructions/Guias/04_Troubleshooting_FAQ.md)**

---

## A história: CONTOSO Angola

A **CONTOSO Angola, Lda** é uma empresa de distribuição com sede em Luanda e cerca de **50 colaboradores** em 5 departamentos: **TI, Financeiro, Recursos Humanos, Marketing e Vendas**.

Hoje a CONTOSO trabalha com computadores soltos, palavras-passe partilhadas, ficheiros em pens USB e e-mail pessoal. O Director de TI, **Paulo Kiala**, contratou-o(a) como **administrador(a) de sistemas** com uma missão em três fases:

| Fase | Tecnologia | O problema que vai resolver |
|---|---|---|
| 1 | **Windows Server** | Não existe identidade central, nem regras, nem ficheiros partilhados com segurança. |
| 2 | **Microsoft 365** | As pessoas precisam de trabalhar fora do escritório sem abrir portas aos atacantes. |
| 3 | **Microsoft Azure** | O servidor do escritório já não chega e a direcção quer cloud com custos controlados. |

O ambiente que constrói no **LAB01** é o mesmo que moderniza no **CAPSTONE**. A narrativa nunca reinicia.

---

## Os laboratórios

| Domingo | Lab | Título | O problema da CONTOSO |
|---|---|---|---|
| Antes | [LAB00](Instructions/Labs/LAB_00_Preparar_o_Ambiente.md) | Preparar o ambiente de laboratório | Não há onde praticar. |
| 1 | [LAB01](Instructions/Labs/LAB_01_Preparar_Windows_Server.md) | Preparar o Windows Server | Servidores com nomes e IPs aleatórios, sem gestão remota. |
| 1 | [LAB02](Instructions/Labs/LAB_02_Criar_Domain_Controller.md) | Criar o Domain Controller | Cada PC tem as suas próprias contas. Não há identidade central. |
| 1 | [LAB03](Instructions/Labs/LAB_03_Estruturar_a_CONTOSO.md) | Estruturar a CONTOSO no AD | 50 pessoas, 5 departamentos, nenhuma organização. |
| 2 | [LAB04](Instructions/Labs/LAB_04_Group_Policy.md) | Group Policy | Cada PC está configurado de forma diferente. |
| 2 | [LAB05](Instructions/Labs/LAB_05_File_Server_e_Permissoes.md) | File Server e permissões | Ficheiros do Financeiro em pens USB e no e-mail. |
| 2 | [LAB06](Instructions/Labs/LAB_06_Operacoes_e_Troubleshooting.md) | Operações e troubleshooting | "Apagaram um utilizador" e "a rede não funciona". |
| 3 | [LAB07](Instructions/Labs/LAB_07_Tenant_e_Dominio.md) | Tenant Microsoft 365 | A empresa não tem presença cloud nem e-mail corporativo. |
| 3 | [LAB08](Instructions/Labs/LAB_08_Identidade_Hibrida.md) | Identidade híbrida | Duas palavras-passe por pessoa: uma local, outra cloud. |
| 3 | [LAB09](Instructions/Labs/LAB_09_MFA_e_Conditional_Access.md) | MFA + Conditional Access | Uma palavra-passe roubada abre tudo. |
| 4 | [LAB10](Instructions/Labs/LAB_10_Microsoft_Intune.md) | Microsoft Intune | Portáteis fora do domínio, sem controlo nem cifra. |
| 4 | [LAB11](Instructions/Labs/LAB_11_Microsoft_Defender.md) | Microsoft Defender | Phishing e malware sem ninguém a ver. |
| 4 | [LAB12](Instructions/Labs/LAB_12_Microsoft_Purview.md) | Microsoft Purview | Dados de cartões e salários enviados por e-mail. |
| 5 | [LAB13](Instructions/Labs/LAB_13_Azure_Governance.md) | Azure Governance | Subscription sem regras: qualquer um cria qualquer coisa. |
| 5 | [LAB14](Instructions/Labs/LAB_14_VNet_e_VM.md) | VNet + VM | O servidor da aplicação precisa de sair do escritório. |
| 5 | [LAB15](Instructions/Labs/LAB_15_Azure_Storage.md) | Azure Storage | Arquivo morto a encher o File Server local. |
| 6 | [LAB16](Instructions/Labs/LAB_16_Azure_Monitor_e_Arc.md) | Azure Monitor + Arc | "O servidor caiu e ninguém soube." |
| 6 | [LAB17](Instructions/Labs/LAB_17_Azure_Backup.md) | Azure Backup | Não há cópia de segurança fora do edifício. |
| 6 | [LAB18](Instructions/Labs/LAB_18_Seguranca_e_Automacao.md) | Segurança, Updates e automação | Ninguém sabe se a cloud está segura nem actualizada. |
| Final | [CAPSTONE](Instructions/Labs/LAB_99_CAPSTONE_Contoso_Modernization.md) | CONTOSO Modernization Project | Provar que consegue desenhar e entregar tudo sozinho(a). |

---

## Como este repositório está organizado

```text
COMBO31/
├── readme.md                     <- está aqui
├── index.md                      <- página inicial do GitHub Pages
├── Instructions/
│   ├── Guias/                    <- comece aqui, ambiente, custos, FAQ
│   └── Labs/                     <- LAB00 a LAB18 + CAPSTONE
├── Allfiles/Labs/                <- scripts e ficheiros usados nos labs
│   ├── 00/  criação automática das VMs em Hyper-V
│   ├── 03/  CSV dos 50 utilizadores da CONTOSO
│   ├── 04/  script de verificação de GPO
│   ├── 06/  scripts de avaria (break/fix)
│   ├── 13/  definição de Azure Policy
│   ├── 18/  ficheiro Bicep
│   └── 99/  modelos do Capstone
└── .github/                      <- modelos para reportar erros nos labs
```

## Regra pedagógica

> **Não se ensina uma funcionalidade sem a fazer.** Se o lab fala de GPO, o aluno cria uma GPO. Se fala de MFA, o aluno configura MFA.

Cada lab segue a mesma estrutura: **Problema -> O que o lab resolve -> Objectivos -> Pré-requisitos -> Topologia -> Passo a passo -> Evidência -> Validação -> Troubleshooting -> Challenge -> Cleanup -> Resultado esperado.**

## Encontrou um erro?

Abra um *Issue* neste repositório usando o modelo disponível, indicando o lab, a tarefa e o passo. Instrutores podem submeter *Pull Requests*. Ver [CONTRIBUTING](.github/CONTRIBUTING.md).

## Avisos

- Todos os nomes, pessoas, empresas, credenciais e dados deste repositório são **fictícios**. A CONTOSO é uma organização fictícia usada apenas para formação.
- As interfaces da Microsoft mudam com frequência. Quando um menu não aparecer exactamente como descrito, procure a mesma opção pelo nome ou abra um Issue.
- Os pontos marcados com **`Actualização 2026/2027`** indicam onde a tecnologia Microsoft mudou em relação a materiais antigos.

---

© 2026 V7A Consultoria e Serviços, Lda / VASSAMA Academy. Material de formação. Ver [LICENSE](LICENSE).
