---
lab:
    title: 'LAB14 - VNet + VM'
    module: 'Domingo 5 - Microsoft Azure Infrastructure'
---

# LAB14 - Virtual Network + Virtual Machine

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB14 | VNet, Subnet, NSG, VNet Peering, NAT Gateway, Virtual Machines, Azure Bastion | 120 min | 5 |

## O problema

A aplicação de encomendas da CONTOSO corre num PC velho debaixo de uma secretária em Talatona. Quando falta a energia ou a Internet do escritório cai, **os vendedores no terreno não conseguem registar encomendas**. A direcção decidiu levar o servidor da aplicação para o Azure.

Mas o Director de TI tem regras: *"O servidor não fica exposto à Internet com RDP aberto. A rede da aplicação fica separada da rede de serviços partilhados. E só passa o tráfego que eu autorizar."*

## O que este lab resolve

A CONTOSO passa a ter **a sua primeira carga de trabalho no Azure**: uma rede de serviços partilhados (hub) e uma rede da aplicação, **ligadas por peering**, com **NSG** a controlar o tráfego, uma **VM Windows Server sem IP público**, administrada com segurança pelo **Azure Bastion**, com **saída para a Internet controlada** por NAT Gateway e **desligada automaticamente** fora de horas.

## Objectivos

- Criar VNets e subnets com um plano de endereçamento sem sobreposição com o on-premises.
- Criar e associar um NSG com regras de entrada.
- Criar uma VM Windows sem IP público e configurar auto-shutdown.
- Ligar à VM com Azure Bastion (Developer).
- Diagnosticar a falta de saída para a Internet em subnets privadas e resolvê-la com NAT Gateway.
- Ligar duas VNets com peering e testar o tráfego permitido e bloqueado.

## Pré-requisitos

- [LAB13](LAB_13_Azure_Governance.md) concluído (RGs, policies, budget).
- Cloud Shell (PowerShell) com as variáveis `$ini`, `$loc`, `$tags` definidas (LAB13, Tarefa 2).

## Topologia

```text
 On-premises CONTOSO: 10.31.10.0/24   (não sobrepor!)

 rg-contoso-net-<ini>                                   rg-contoso-app-<ini>
 ┌──────────────────────────────┐   peering   ┌──────────────────────────────────┐
 │ vnet-contoso-hub-<ini>       │◀──────────▶ │ vnet-contoso-app-<ini>           │
 │ 10.50.0.0/16                 │             │ 10.60.0.0/16                     │
 │  snet-shared 10.50.1.0/24    │             │  snet-app 10.60.1.0/24           │
 │   vm-contoso-tst01 (Linux)   │             │   nsg-snet-app-<ini>             │
 └──────────────────────────────┘             │   vm-contoso-app01 (WS2025, IIS) │
                                              │   natgw-contoso-<ini> ──▶ Internet│
                                              └──────────────────────────────────┘
 Administração: Azure Bastion Developer (sem IP público nas VMs)
```

> **Porquê 10.50 e 10.60?** Se um dia a CONTOSO ligar o escritório ao Azure por VPN, as redes **não podem sobrepor-se** à rede local (10.31.10.0/24). O plano de endereçamento decide-se no primeiro dia.

## Credenciais

| VM | Utilizador | Palavra-passe |
|---|---|---|
| `vm-contoso-app01` | `azureadmin` | Escolha uma palavra-passe forte (12+ caracteres). Não a escreva no repositório. |
| `vm-contoso-tst01` | `azureadmin` | A mesma |

---

## Exercício 1: Rede

### Tarefa 1: Criar as VNets

1. No Cloud Shell (o RG de rede tem Lock *CanNotDelete*, o que **não** impede criar recursos dentro dele):

   ```powershell
   $snetShared = New-AzVirtualNetworkSubnetConfig -Name 'snet-shared' -AddressPrefix '10.50.1.0/24'
   $hub = New-AzVirtualNetwork -Name "vnet-contoso-hub-$ini" -ResourceGroupName "rg-contoso-net-$ini" `
            -Location $loc -AddressPrefix '10.50.0.0/16' -Subnet $snetShared -Tag $tags

   $snetApp = New-AzVirtualNetworkSubnetConfig -Name 'snet-app' -AddressPrefix '10.60.1.0/24'
   $app = New-AzVirtualNetwork -Name "vnet-contoso-app-$ini" -ResourceGroupName "rg-contoso-net-$ini" `
            -Location $loc -AddressPrefix '10.60.0.0/16' -Subnet $snetApp -Tag $tags
   ```

1. No portal, abra `vnet-contoso-app-<ini>` > **Subnets** > `snet-app`. Observe a opção **Private subnet** / **Default outbound access**: em VNets novas fica **activa** (subnet privada) por omissão.

> **`Actualização 2026/2027`:** desde **31 de Março de 2026**, as VNets novas criam **subnets privadas por omissão**. As VMs nessas subnets **deixam de ter acesso implícito à Internet** ("default outbound access"). É preciso um método de saída **explícito**: NAT Gateway, IP público ou Load Balancer. Materiais antigos assumem que "uma VM nova tem Internet": já não é verdade. Vai ver isto na prática no Exercício 3.

### Tarefa 2: NSG da subnet da aplicação

1. Crie o NSG com as regras de entrada:

   ```powershell
   $r1 = New-AzNetworkSecurityRuleConfig -Name 'Allow-Bastion-RDP' -Priority 100 -Direction Inbound -Access Allow `
         -Protocol Tcp -SourceAddressPrefix '168.63.129.16' -SourcePortRange '*' -DestinationAddressPrefix '*' -DestinationPortRange 3389
   $r2 = New-AzNetworkSecurityRuleConfig -Name 'Allow-HTTP-From-Hub' -Priority 200 -Direction Inbound -Access Allow `
         -Protocol Tcp -SourceAddressPrefix '10.50.0.0/16' -SourcePortRange '*' -DestinationAddressPrefix '*' -DestinationPortRange 80
   $nsg = New-AzNetworkSecurityGroup -Name "nsg-snet-app-$ini" -ResourceGroupName "rg-contoso-net-$ini" -Location $loc `
          -SecurityRules $r1, $r2 -Tag $tags

   Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $app -Name 'snet-app' -AddressPrefix '10.60.1.0/24' -NetworkSecurityGroup $nsg |
       Set-AzVirtualNetwork
   ```

1. No portal, abra o NSG e veja também as **regras por omissão** (65000+): `AllowVnetInBound`, `AllowAzureLoadBalancerInBound`, `DenyAllInBound`.

> **Porquê `168.63.129.16`?** É o IP virtual da plataforma Azure usado pelo **Bastion Developer** para chegar à VM. Com esta regra, o RDP só é possível **através do Bastion**, nunca a partir da Internet.

> **Pergunta:** a regra `AllowVnetInBound` (65000) permite tráfego entre VNets em peering. Então para que serve a regra 200? *(Resposta no Challenge.)*

---

## Exercício 2: Máquina virtual

### Tarefa 3: Criar a VM da aplicação (portal)

1. Portal > **Virtual machines > Create > Azure virtual machine**.
1. **Basics:**
   - RG `rg-contoso-app-<ini>`, nome `vm-contoso-app01`, região do curso.
   - **Availability options:** No infrastructure redundancy required.
   - **Security type:** Trusted launch.
   - **Image:** Windows Server 2025 Datacenter: Azure Edition - x64 Gen2.
   - **Size:** `Standard_B2s` (ou `Standard_B2als_v2` / `Standard_B2as_v2` se indisponível). **Não use tamanhos grandes**: a conta gratuita tem quota limitada de vCPUs.
   - Utilizador `azureadmin` e palavra-passe forte.
   - **Public inbound ports:** **None**.
1. **Disks:** OS disk **Standard SSD (LRS)**.
1. **Networking:**
   - VNet `vnet-contoso-app-<ini>`, subnet `snet-app`.
   - **Public IP:** **None**.
   - **NIC network security group:** **None** (o NSG já está na subnet).
1. **Management:** **Enable auto-shutdown** às `19:00`, fuso **(UTC+01:00) West Central Africa**, notificação para o seu e-mail.
1. **Tags:** confirme que herdou `CentroCusto` (policy do LAB13) e adicione as restantes tags da CONTOSO.
1. **Review + create > Create**. Aguarde 3-5 minutos.

### Tarefa 4: Ligar com o Bastion

1. Abra `vm-contoso-app01` > **Connect > Connect via Bastion**.
1. Se for proposto, seleccione **Deploy Bastion Developer** (gratuito). Aguarde.
1. Introduza `azureadmin` e a palavra-passe > **Connect**. A sessão RDP abre **no browser**, por HTTPS.

> **Bastion Developer indisponível na sua região?** Use **Configure manually** > SKU **Basic** (exige uma subnet `AzureBastionSubnet` /26 em `vnet-contoso-app-<ini>`, ex.: `10.60.254.0/26`, e um IP público Standard). **O Basic tem custo por hora: elimine-o no fim do lab.**

### Tarefa 5: Instalar o IIS (a "aplicação")

1. Dentro da VM (sessão Bastion), PowerShell como administrador:

   ```powershell
   Install-WindowsFeature Web-Server -IncludeManagementTools
   Set-Content C:\inetpub\wwwroot\index.html '<h1>CONTOSO - Aplicação de Encomendas</h1><p>Servidor: vm-contoso-app01 (Azure)</p>'
   ```

   Alternativa sem entrar na VM: **VM > Operations > Run command > RunPowerShellScript**.

---

## Exercício 3: Saída para a Internet

### Tarefa 6: Diagnosticar

1. Dentro da VM, PowerShell:

   ```powershell
   Test-NetConnection www.microsoft.com -Port 443
   ```

   Resultado esperado: **`TcpTestSucceeded : False`**. A VM está numa subnet privada e não tem nenhum método de saída explícito. Sem saída, a VM **não recebe Windows Update** e, nos próximos labs, **não conseguiria enviar dados para o Azure Monitor**.

### Tarefa 7: NAT Gateway

1. No Cloud Shell:

   ```powershell
   $pip = New-AzPublicIpAddress -Name "pip-natgw-contoso-$ini" -ResourceGroupName "rg-contoso-net-$ini" -Location $loc `
          -Sku Standard -AllocationMethod Static -Tag $tags
   $nat = New-AzNatGateway -Name "natgw-contoso-$ini" -ResourceGroupName "rg-contoso-net-$ini" -Location $loc `
          -Sku Standard -PublicIpAddress $pip -IdleTimeoutInMinutes 4 -Tag $tags

   $app = Get-AzVirtualNetwork -Name "vnet-contoso-app-$ini" -ResourceGroupName "rg-contoso-net-$ini"
   $nsg = Get-AzNetworkSecurityGroup -Name "nsg-snet-app-$ini" -ResourceGroupName "rg-contoso-net-$ini"
   Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $app -Name 'snet-app' -AddressPrefix '10.60.1.0/24' `
       -NetworkSecurityGroup $nsg -NatGateway $nat | Set-AzVirtualNetwork
   $pip.IpAddress
   ```

1. Na VM, repita o `Test-NetConnection`: agora **`True`**. Abra `https://ifconfig.me` no Edge da VM: o IP mostrado é o do NAT Gateway.

> **Custos:** o NAT Gateway e o seu IP público têm custo por hora (baixo, mas contínuo). São necessários até ao LAB18. **Elimine-os no Cleanup do LAB18.**

> **Três tipos de IP neste lab:** **privado** (`10.60.1.x`, a VM na VNet), **público de saída** (o do NAT Gateway, partilhado e só de saída) e **nenhum IP público de entrada** na VM. A administração entra pelo Bastion.

---

## Exercício 4: Peering

### Tarefa 8: Criar uma VM de teste no hub

Uma VM Linux pequena, só para testes, na rede hub. Portal > **Virtual machines > Create**:

1. RG `rg-contoso-app-<ini>`, nome `vm-contoso-tst01`, região do curso.
1. **Image:** Ubuntu Server 24.04 LTS - x64 Gen2. **Size:** `Standard_B1s` (ou `Standard_B2ats_v2`).
1. **Authentication type:** Password, utilizador `azureadmin`. **Public inbound ports:** None.
1. **Networking:** VNet `vnet-contoso-hub-<ini>`, subnet `snet-shared`, **Public IP: None**, **NIC NSG: None**.
1. **Tags:** as da CONTOSO. **Create**.

### Tarefa 9: Testar antes do peering

1. Ligue-se à `vm-contoso-tst01` com **Connect > Bastion** (SSH, utilizador `azureadmin`).
1. Execute `curl -m 5 http://10.60.1.4` (confirme o IP privado da `vm-contoso-app01` no portal). **Falha** (timeout): as VNets estão isoladas.

### Tarefa 10: Criar o peering

1. No Cloud Shell:

   ```powershell
   $hub = Get-AzVirtualNetwork -Name "vnet-contoso-hub-$ini" -ResourceGroupName "rg-contoso-net-$ini"
   $app = Get-AzVirtualNetwork -Name "vnet-contoso-app-$ini" -ResourceGroupName "rg-contoso-net-$ini"
   Add-AzVirtualNetworkPeering -Name 'peer-hub-to-app' -VirtualNetwork $hub -RemoteVirtualNetworkId $app.Id
   Add-AzVirtualNetworkPeering -Name 'peer-app-to-hub' -VirtualNetwork $app -RemoteVirtualNetworkId $hub.Id
   Get-AzVirtualNetworkPeering -VirtualNetworkName "vnet-contoso-hub-$ini" -ResourceGroupName "rg-contoso-net-$ini" |
       Select-Object Name, PeeringState
   ```

   `PeeringState` deve ser **Connected**. O peering tem **dois lados**: falta um e não funciona.

1. Na `vm-contoso-tst01`: `curl http://10.60.1.4` > devolve a página **CONTOSO - Aplicação de Encomendas**.

### Tarefa 11: Provar que o NSG manda

1. Na `vm-contoso-tst01`, teste a porta RDP da VM da aplicação a partir do hub:

   ```bash
   nc -zv -w 5 10.60.1.4 3389
   ```

   **Funciona** (`succeeded`): a regra por omissão `AllowVnetInBound` (65000) deixa passar **tudo** o que vem de uma VNet em peering. O Director de TI não quer isto: do hub, só HTTP.

1. Adicione ao NSG uma regra **Deny** de prioridade **300** para `10.50.0.0/16` -> qualquer porta, no Cloud Shell:

   ```powershell
   $nsg = Get-AzNetworkSecurityGroup -Name "nsg-snet-app-$ini" -ResourceGroupName "rg-contoso-net-$ini"
   $nsg | Add-AzNetworkSecurityRuleConfig -Name 'Deny-Hub-Other' -Priority 300 -Direction Inbound -Access Deny `
       -Protocol '*' -SourceAddressPrefix '10.50.0.0/16' -SourcePortRange '*' -DestinationAddressPrefix '*' -DestinationPortRange '*' |
       Set-AzNetworkSecurityGroup
   ```

1. Na `vm-contoso-tst01`, repita os dois testes:
   - `nc -zv -w 5 10.60.1.4 3389` **falha** (timeout): a regra 300 nega antes de chegar à 65000.
   - `curl -m 5 http://10.60.1.4` **continua a funcionar**: a regra 200 tem número de prioridade mais baixo e é avaliada primeiro.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB14`:

1. Captura da topologia: **vnet-contoso-app-<ini> > Monitoring > Diagram** (ou *Network Watcher > Topology*).
1. `Test-NetConnection` **antes** (False) e **depois** (True) do NAT Gateway.
1. Estado `Connected` dos dois peerings.
1. Saída do `curl` com a página da CONTOSO a partir do hub.
1. Captura do auto-shutdown configurado.

## Validação

- [ ] Duas VNets sem sobreposição com o on-premises.
- [ ] NSG na subnet da aplicação: RDP só via Bastion, HTTP só do hub, resto do hub negado.
- [ ] `vm-contoso-app01` sem IP público, com IIS e auto-shutdown às 19h00.
- [ ] Saída para a Internet via NAT Gateway.
- [ ] Peering bidireccional funcional.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `RequestDisallowedByPolicy` | Região errada ou tag em falta (LAB13) | Use `$loc` e `-Tag $tags`. |
| `SkuNotAvailable` / quota | Tamanho indisponível na região ou quota da conta gratuita | Tente outro tamanho da série B; veja **Subscriptions > Usage + quotas**. |
| Bastion: *"connection error"* | NSG sem a regra para `168.63.129.16` | Tarefa 2. |
| Bastion Developer não liga à VM do hub depois do peering | O Developer não suporta ligação via VNets em peering | Ligue a partir do Bastion da própria VNet da VM. |
| Aviso sobre **Network Watcher** / `NetworkWatcherRG` | A policy de tag obrigatória (LAB13) bloqueou o RG automático | Crie o Network Watcher manualmente: `New-AzNetworkWatcher -Name "nw-contoso-$ini" -ResourceGroupName "rg-contoso-net-$ini" -Location $loc -Tag $tags`. |
| `curl` falha após peering | Firewall do Windows ou IIS não instalado | Confirme `Get-WindowsFeature Web-Server` e a regra *World Wide Web Services (HTTP Traffic-In)*. |

## Challenge

1. **Resposta à pergunta da Tarefa 2:** sem a regra 300, a regra 200 seria redundante, porque `AllowVnetInBound` já deixava passar tudo do hub. Com a regra 300, a 200 passa a ser a **única** excepção permitida. Prove-o com **Network Watcher > IP flow verify** na `vm-contoso-app01`, para tráfego de entrada vindo de `10.50.1.4` nas portas 80 e 3389, e indique que regra decidiu cada caso.
1. Se fez o Challenge do LAB13: entre como `edson.lukeny` e prove que consegue **parar e iniciar** a `vm-contoso-app01` mas não a consegue **eliminar**.

## Cleanup

1. **Elimine a VM de teste** (já não é necessária):

   ```powershell
   Remove-AzVM -ResourceGroupName "rg-contoso-app-$ini" -Name 'vm-contoso-tst01' -Force
   Get-AzDisk -ResourceGroupName "rg-contoso-app-$ini" | Where-Object Name -like 'vm-contoso-tst01*' | Remove-AzDisk -Force
   Get-AzNetworkInterface -ResourceGroupName "rg-contoso-app-$ini" | Where-Object Name -like 'vm-contoso-tst01*' | Remove-AzNetworkInterface -Force
   ```

1. **Pare a `vm-contoso-app01`** (Stop = deallocated) se não continuar hoje. **Não a elimine**: é usada até ao LAB18.
1. Se criou **Bastion Basic**, elimine-o.

## Resultado esperado

A aplicação da CONTOSO corre no Azure, numa rede segmentada, sem portas expostas à Internet, com saída controlada e custos limitados pelo auto-shutdown.

**Próximo lab:** [LAB15 - Azure Storage](LAB_15_Azure_Storage.md)
