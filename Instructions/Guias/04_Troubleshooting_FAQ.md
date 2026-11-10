---
title: '04 - Troubleshooting geral e FAQ'
---

# Troubleshooting geral e FAQ

## Hyper-V e VMs

| Sintoma | Causa provável | Solução |
|---|---|---|
| "Hyper-V cannot be installed: virtualization support is disabled in the firmware" | Virtualização desligada na BIOS/UEFI | Active Intel VT-x / AMD-V (SVM) na BIOS. |
| Windows 11 não instala: "This PC can't run Windows 11" | VM sem TPM ou Secure Boot | VM de Geração 2, active **Secure Boot** e **Trusted Platform Module** nas definições da VM. |
| VM sem Internet | Falta o NAT ou o gateway | No portátil: `Get-NetNat`. Na VM: gateway `10.31.10.1`, DNS `10.31.10.10`. |
| VMs lentas | RAM insuficiente | Desligue VMs que o lab não usa. Use memória dinâmica. |
| Portátil com VMware/VirtualBox deixou de funcionar | Hyper-V ocupa o hypervisor | Use um hypervisor de cada vez ou versões compatíveis com Hyper-V. |

## Domínio e DNS

| Sintoma | Solução |
|---|---|
| "An Active Directory Domain Controller for the domain could not be contacted" ao juntar ao domínio | O DNS da máquina tem de ser `10.31.10.10`. Teste `nslookup corp.contoso.com`. |
| "The trust relationship between this workstation and the primary domain failed" | Restauro de checkpoint desalinhado. `Test-ComputerSecureChannel -Repair -Credential CONTOSO\Administrator` |
| GPO não aplica | `gpupdate /force` e `gpresult /r`. Confirme que o objecto está na OU certa. |

## Microsoft 365 e Entra

| Sintoma | Solução |
|---|---|
| Não consigo criar trial Business Premium | Use outro e-mail ou peça um tenant de reserva à academia. |
| Fiquei bloqueado(a) por Conditional Access | Entre com a conta **break-glass** (LAB07) e corrija a política. |
| Utilizadores não aparecem no Entra após o LAB08 | `Start-ADSyncSyncCycle -PolicyType Delta` no ADM01. Confirme o filtro de OU. |
| Políticas Intune não chegam ao dispositivo | Em CL02: **Definições > Contas > Acesso ao trabalho ou escola > Informações > Sincronizar**. Pode levar 15-30 min. |
| Sensitivity labels não aparecem no Office | Publicação pode demorar até 24 h. Continue o lab e valide no dia seguinte. |

## Azure

| Sintoma | Solução |
|---|---|
| "RequestDisallowedByPolicy" | Foi a sua própria Azure Policy (LAB13). Leia a mensagem: falta uma tag ou a região não é permitida. |
| "SkuNotAvailable" / "QuotaExceeded" ao criar VM | Escolha outro tamanho (ex.: `Standard_B2s`, `Standard_B2als_v2`) ou outra região permitida. |
| VM no Azure sem Internet | VNets novas são privadas por omissão. Ver LAB14, Tarefa "Saída para a Internet". |
| Bastion Developer não aparece | A região não suporta Developer. Use Basic e elimine no fim do lab. |

## FAQ

**Posso usar VMware Workstation em vez de Hyper-V?**
Sim. Crie uma rede "Host-only" ou "NAT" com a subnet 10.31.10.0/24 e gateway 10.31.10.1 (no VMware NAT o gateway costuma ser .2: ajuste o gateway nas VMs). O script automático do LAB00 é apenas para Hyper-V.

**Posso usar Windows Server 2022?**
Sim, todos os labs funcionam. Os ecrãs podem diferir ligeiramente.

**O trial do M365 expirou antes de terminar.**
Peça um tenant de reserva à academia. Os labs LAB07-LAB09 podem ser repetidos num tenant novo em cerca de 3 horas.

**Perdi uma aula.**
É exactamente para isto que os labs são auto-guiados. Faça os labs desse domingo em casa e traga as evidências ao próximo checkpoint.
