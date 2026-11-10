---
title: '01 - Mapa da Jornada'
---

# Mapa da Jornada - "Do Datacenter à Cloud"

## Arquitectura que vai construir

```text
WINDOWS SERVER (on-premises, Hyper-V)            Domingos 1-2
│  AD DS · DNS · DHCP · GPO · File Server · Backup
│
▼  Microsoft Entra Connect Sync (Password Hash Sync)
MICROSOFT ENTRA ID                               Domingo 3
│  Utilizadores híbridos · MFA · SSPR · Conditional Access
│
▼
MICROSOFT 365                                    Domingo 4
│  Intune · Defender · Purview
│
▼  Azure Arc (o servidor local passa a ser visto pelo Azure)
MICROSOFT AZURE                                  Domingos 5-6
   Governance · VNet · VM · Storage · Monitor · Backup · Defender for Cloud
```

## Sequência e dependências

| Lab | Depende de | Produz (usado mais tarde) |
|---|---|---|
| LAB00 | - | Hyper-V, rede `CMB31-LAN`, 5 VMs instaladas |
| LAB01 | LAB00 | Servidores com nome, IP fixo e gestão remota (WAC) |
| LAB02 | LAB01 | Domínio `corp.contoso.com` e DNS |
| LAB03 | LAB02 | OUs, 50 utilizadores, grupos, máquinas no domínio |
| LAB04 | LAB03 | GPOs da CONTOSO |
| LAB05 | LAB03 | File Server `\\CMB31-SRV01` com shares por departamento |
| LAB06 | LAB02-05 | DHCP, AD Recycle Bin, Windows Server Backup |
| LAB07 | - (só Internet) | Tenant M365, administradores, licenças |
| LAB08 | LAB03 + LAB07 | Utilizadores AD sincronizados para o Entra ID |
| LAB09 | LAB08 | MFA, SSPR, políticas de Conditional Access |
| LAB10 | LAB09 | CL02 gerido pelo Intune, compliance e BitLocker |
| LAB11 | LAB10 | CL02 no Defender, políticas anti-phishing |
| LAB12 | LAB07 | Sensitivity labels, DLP, retenção, auditoria |
| LAB13 | LAB07 | Subscription governada (RG, tags, RBAC, Policy, budget) |
| LAB14 | LAB13 | VNets, peering, VM no Azure com Bastion |
| LAB15 | LAB13 | Storage account, Blob, Azure Files |
| LAB16 | LAB14 + LAB01 | Log Analytics, alertas, SRV01 ligado via Azure Arc |
| LAB17 | LAB14 | VM protegida com Azure Backup e restauro testado |
| LAB18 | LAB14 + LAB16 | Defender for Cloud, Update Manager, deploy com Bicep |
| CAPSTONE | Todos | Projecto de modernização documentado |

> LAB07 e LAB12-LAB15 **não dependem** das VMs locais. Se o seu portátil avariar, pode avançar com estes labs enquanto resolve.

## Os 6 domingos

| Domingo | Tema | Labs | Resultado concreto no fim do dia |
|---|---|---|---|
| 1 | Windows Server - Core Infrastructure | LAB01, LAB02, LAB03 | A CONTOSO tem domínio, DNS e 50 utilizadores organizados. |
| 2 | Windows Server - Administration & Security | LAB04, LAB05, LAB06 | Postos configurados por GPO, ficheiros protegidos, recuperação testada. |
| 3 | Microsoft 365 - Identity & Access | LAB07, LAB08, LAB09 | Os utilizadores entram na cloud com a mesma palavra-passe e com MFA. |
| 4 | Microsoft 365 - Security & Compliance | LAB10, LAB11, LAB12 | Dispositivos geridos, ameaças visíveis, dados sensíveis protegidos. |
| 5 | Azure - Infrastructure | LAB13, LAB14, LAB15 | Primeira carga de trabalho no Azure, com regras e custos sob controlo. |
| 6 | Azure - Operations + Capstone | LAB16, LAB17, LAB18 + CAPSTONE | Ambiente híbrido monitorizado, com backup e seguro. |

## Horário padrão de um domingo em sala

| Hora | Actividade |
|---|---|
| 09:00-09:20 | Recap + problema do dia |
| 09:20-10:30 | Conceitos essenciais + demonstração |
| 10:30-10:45 | Pausa |
| 10:45-12:30 | Lab 1 do dia |
| 12:30-13:30 | Almoço |
| 13:30-14:15 | Lab 2 do dia (início) |
| 14:15-15:30 | Lab 2 (fim) + Lab 3 |
| 15:30-16:00 | Troubleshooting + Checkpoint |

> O Lab 3 de cada domingo pode terminar em casa. É por isso que todos os labs são auto-guiados.
