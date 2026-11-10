---
title: '03 - Custos e Limpeza'
---

# Custos e Limpeza - como não gastar dinheiro por engano

## O que é gratuito

| Recurso | Custo | Notas |
|---|---|---|
| Windows Server 2025 / Windows 11 Evaluation | Gratuito | 180 / 90 dias |
| Microsoft 365 Business Premium trial | Gratuito durante o trial | Cancele a renovação automática se introduzir cartão |
| Microsoft Entra ID P1 | Incluído no Business Premium | Conditional Access disponível |
| Azure Policy, RBAC, tags, Resource Groups | Gratuito | |
| Azure Bastion **Developer** | Gratuito | Disponível em regiões seleccionadas |
| Defender for Cloud **Foundational CSPM** | Gratuito | |
| Azure Arc (servidor ligado, inventário) | Gratuito | Serviços adicionados ao Arc podem ser pagos |

## O que custa dinheiro (e quanto tempo pode ficar ligado)

| Recurso | Lab | Regra |
|---|---|---|
| Máquina virtual Azure | LAB14, LAB16-18 | **Pare (Stop / Deallocate)** sempre que não estiver a usar. Configure auto-shutdown. |
| Disco gerido da VM | LAB14 | Paga mesmo com a VM parada. Elimine no fim do domingo 6. |
| Bastion Basic/Standard | LAB14 (alternativa) | Custo por hora. **Elimine no fim do lab.** |
| NAT Gateway | LAB14 (opcional) | Custo por hora. Elimine no fim do lab. |
| Log Analytics | LAB16 | Pequeno, por GB ingerido. Mantenha retenção mínima. |
| Recovery Services vault | LAB17 | Por instância protegida + armazenamento. Siga o Cleanup do LAB17. |
| Defender for Servers Plan 1/2 | LAB18 (opcional) | Período de avaliação, depois pago. **Desligue no fim do lab.** |

## Três regras de ouro

1. **Budget primeiro.** No LAB13 cria um budget com alerta. Não avance para o LAB14 sem ele.
2. **Auto-shutdown em todas as VMs** às 19h00 (hora de Luanda).
3. **No fim de cada lab Azure, faça o Cleanup indicado.** No fim do curso, elimine todos os `rg-contoso-*`.

## Limpeza total no fim do curso

```powershell
# Azure Cloud Shell (PowerShell) - lista e elimina todos os Resource Groups da CONTOSO
Get-AzResourceGroup | Where-Object ResourceGroupName -like 'rg-contoso-*' |
    Select-Object ResourceGroupName, Location

# Depois de confirmar a lista acima:
Get-AzResourceGroup | Where-Object ResourceGroupName -like 'rg-contoso-*' |
    Remove-AzResourceGroup -Force -AsJob
```

> Se o vault do LAB17 ainda tiver itens protegidos, a eliminação do Resource Group falha. Siga primeiro o Cleanup do LAB17.

## Subscription da academia

Na subscription da academia cada aluno tem **um Resource Group** e permissões apenas sobre ele. Nesse caso:

- Use sempre o seu RG (o instrutor indica o nome).
- Ignore os passos que exigem permissões ao nível da subscription (estão assinalados como **[Subscription própria]**).
- Não elimine recursos de outros alunos.
