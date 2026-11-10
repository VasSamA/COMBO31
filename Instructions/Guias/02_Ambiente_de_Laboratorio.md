---
title: '02 - Ambiente de Laboratório'
---

# Ambiente de Laboratório

## Máquinas virtuais (on-premises simulado)

| VM | Função | Sistema operativo | vCPU | RAM (dinâmica) | IP |
|---|---|---|---|---|---|
| **CMB31-DC01** | Domain Controller, DNS, DHCP | Windows Server 2025 Datacenter (Desktop Experience) | 2 | 2-4 GB | 10.31.10.10 |
| **CMB31-SRV01** | File Server | Windows Server 2025 Datacenter **Server Core** | 2 | 1-2 GB | 10.31.10.20 |
| **CMB31-ADM01** | Servidor de administração: Windows Admin Center, RSAT, Entra Connect Sync | Windows Server 2025 Datacenter (Desktop Experience) | 2 | 2-4 GB | 10.31.10.30 |
| **CMB31-CL01** | Posto de trabalho no domínio (utilizador do escritório) | Windows 11 Enterprise | 2 | 2-4 GB | 10.31.10.101 (LAB01), DHCP a partir do LAB06 |
| **CMB31-CL02** | Portátil cloud-native (Entra joined + Intune) | Windows 11 Enterprise | 2 | 2-4 GB | DHCP |

> **Gestão de memória:** não precisa de ter as 5 VMs ligadas ao mesmo tempo. Cada lab indica quais ligar. Com 16 GB de RAM no portátil, mantenha no máximo 3 VMs ligadas.

## Rede

| Item | Valor |
|---|---|
| Virtual switch Hyper-V | `CMB31-LAN` (Internal) |
| Rede | 10.31.10.0/24 |
| Gateway (NAT no portátil) | 10.31.10.1 |
| DNS dos servidores e clientes | 10.31.10.10 (CMB31-DC01) |
| DNS forwarders (no DC) | 1.1.1.1 e 8.8.8.8 |
| Âmbito DHCP (LAB06) | 10.31.10.100 a 10.31.10.150 |
| Domínio AD | `corp.contoso.com` |
| NetBIOS | `CONTOSO` |

```text
                Internet
                    │
          ┌─────────┴─────────┐
          │  Portátil (host)  │  NAT 10.31.10.1
          └─────────┬─────────┘
                    │ vSwitch CMB31-LAN (Internal)
   ┌────────┬───────┼────────┬─────────┐
 DC01     SRV01   ADM01     CL01      CL02
 .10      .20     .30       .101/DHCP DHCP
```

## Credenciais (fictícias, apenas para laboratório)

| Conta | Palavra-passe | Uso |
|---|---|---|
| `Administrator` (local) | `Pa55w.rd2027!` | Antes do domínio (LAB00-LAB01) |
| `CONTOSO\Administrator` | `Pa55w.rd2027!` | Administração do domínio |
| Utilizadores CONTOSO (CSV) | `Contoso#2027` | Utilizadores de teste (LAB03+) |
| DSRM | `Pa55w.rd2027!` | Modo de recuperação do AD |
| Tenant M365 / Azure | Definida por si | Nunca escreva estas credenciais no repositório |

> Estas palavras-passe existem apenas porque é um laboratório isolado. Em produção, nunca reutilize palavras-passe nem as documente em texto simples.

## Microsoft 365 e Azure

| Item | Convenção |
|---|---|
| Tenant | `contoso<iniciais><nn>.onmicrosoft.com` (ex.: `contosoosm01`) |
| Conta de administração cloud | `admin@<tenant>.onmicrosoft.com` |
| Conta break-glass | `bg-admin01@<tenant>.onmicrosoft.com` |
| Subscription | A sua (Azure gratuita) ou `SUB-VA-<ano>-Tx` da academia |
| Resource Groups | `rg-contoso-<função>-<iniciais>` (ex.: `rg-contoso-net-osm`) |
| Região Azure | Definida no LAB13 (recomendado: uma região permitida pela Policy e com Bastion Developer) |

> **Recomendação forte:** active a subscription Azure com a **mesma conta de administração do tenant M365** (LAB13). Assim os utilizadores sincronizados no LAB08 existem no mesmo Entra ID e podem receber papéis RBAC no Azure.

## Checkpoints Hyper-V recomendados

| Nome do checkpoint | Quando |
|---|---|
| `00-Instalado` | Fim do LAB00 |
| `01-Configurado` | Fim do LAB01 |
| `03-Dominio-Estruturado` | Fim do LAB03 |
| `06-Fim-Windows-Server` | Fim do LAB06 |
| `08-Hibrido` | Fim do LAB08 |

> **Atenção ao DC:** restaurar um checkpoint antigo do Domain Controller depois de os outros servidores terem mudado a palavra-passe da conta de computador pode partir a relação de confiança. Restaure **todas as VMs para o mesmo checkpoint**.
