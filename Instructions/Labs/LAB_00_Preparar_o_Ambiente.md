---
lab:
    title: 'LAB00 - Preparar o ambiente de laboratório'
    module: 'Antes do Domingo 1'
---

# LAB00 - Preparar o ambiente de laboratório

| Código | Tecnologia | Duração | Onde |
|---|---|---|---|
| LAB00 | Hyper-V / Windows Server | 2h a 3h (a maior parte é espera de instalação) | **Em casa, antes do Domingo 1** |

## O problema

A CONTOSO quer modernizar a sua infraestrutura, mas não pode fazer testes em produção: um erro num Domain Controller real pára a empresa inteira. Antes de tocar em qualquer servidor, o administrador precisa de um **laboratório isolado** onde possa construir, partir e reconstruir sem consequências.

## O que este lab resolve

No fim deste lab terá no seu portátil uma **réplica isolada do datacenter da CONTOSO**: uma rede privada com saída para a Internet e cinco máquinas virtuais com o sistema operativo instalado, prontas para o LAB01.

## Objectivos

- Activar o Hyper-V no portátil.
- Criar a rede de laboratório `CMB31-LAN` com NAT.
- Criar as 5 VMs da CONTOSO (manual ou por script).
- Instalar Windows Server 2025 e Windows 11.
- Criar o primeiro checkpoint.

## Pré-requisitos

- Portátil com Windows 11 **Pro, Enterprise ou Education** (Hyper-V não existe no Windows Home).
- 16 GB RAM (mínimo), 150 GB livres em SSD, virtualização activa na BIOS/UEFI.
- ISOs descarregadas do **Microsoft Evaluation Center**:
  - Windows Server 2025 (ISO, edição Evaluation)
  - Windows 11 Enterprise (ISO, edição Evaluation)

> **Windows Home?** Use VMware Workstation e siga a FAQ do [Guia de Troubleshooting](../Guias/04_Troubleshooting_FAQ.md). Os valores de IP e nomes são os mesmos.

## Topologia

Ver [Ambiente de Laboratório](../Guias/02_Ambiente_de_Laboratorio.md).

```text
Portátil (10.31.10.1, NAT) ── CMB31-LAN ── DC01 .10 │ SRV01 .20 │ ADM01 .30 │ CL01 │ CL02
```

## Credenciais

| Conta | Palavra-passe |
|---|---|
| `Administrator` local de cada servidor | `Pa55w.rd2027!` |
| Conta local dos clientes Windows 11 | `labadmin` / `Pa55w.rd2027!` |

---

## Exercício 1: Preparar o portátil

### Tarefa 1: Confirmar a virtualização e activar o Hyper-V

1. Abra o **Gestor de Tarefas > Desempenho > CPU** e confirme **Virtualização: Activada**. Se estiver desactivada, active Intel VT-x ou AMD-V/SVM na BIOS/UEFI.
1. Abra o **PowerShell como Administrador** e execute:

   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
   ```

1. Reinicie o portátil quando pedido.
1. Após o reinício, confirme:

   ```powershell
   Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | Select-Object State
   ```

   Resultado esperado: `State : Enabled`.

### Tarefa 2: Organizar as pastas

1. Crie a pasta `D:\Hyper-V\CMB31` (ou `C:\Hyper-V\CMB31` se só tiver um disco).
1. Crie a pasta `D:\ISO` e copie para lá as duas ISOs. Renomeie-as para `WS2025.iso` e `Win11Ent.iso`.
1. Crie a pasta `Documentos\COMBO\Evidencias`. Aqui guardará as evidências de todos os labs.

---

## Exercício 2: Criar a rede e as VMs

Pode seguir o **caminho A (script, recomendado)** ou o **caminho B (manual, para quem quer perceber cada passo)**.

### Tarefa 3A: Criar tudo com o script (recomendado)

1. Descarregue este repositório (**Code > Download ZIP**) e extraia-o, por exemplo para `D:\COMBO31`.
1. No PowerShell como Administrador:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   cd D:\COMBO31\Allfiles\Labs\00
   .\New-CMB31Lab.ps1 -ServerIso 'D:\ISO\WS2025.iso' -ClientIso 'D:\ISO\Win11Ent.iso' -VmPath 'D:\Hyper-V\CMB31'
   ```

1. Confirme que aparecem 5 VMs `CMB31-*` no **Hyper-V Manager**.

### Tarefa 3B: Criar tudo manualmente (alternativa)

1. Crie o switch e o NAT:

   ```powershell
   New-VMSwitch -Name 'CMB31-LAN' -SwitchType Internal
   $nic = Get-NetAdapter -Name 'vEthernet (CMB31-LAN)'
   New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 10.31.10.1 -PrefixLength 24
   New-NetNat -Name 'CMB31-NAT' -InternalIPInterfaceAddressPrefix '10.31.10.0/24'
   ```

1. No **Hyper-V Manager**, crie cada VM com **New > Virtual Machine**, usando os valores da tabela do [Ambiente](../Guias/02_Ambiente_de_Laboratorio.md):
   - **Generation 2**, memória dinâmica, rede `CMB31-LAN`, disco novo (60 GB servidores, 80 GB clientes), ISO correcta.
1. Para **CMB31-CL01** e **CMB31-CL02**: **Settings > Security**, marque **Enable Trusted Platform Module**.
1. Em todas: **Settings > Checkpoints**, desmarque **Use automatic checkpoints**.

---

## Exercício 3: Instalar os sistemas operativos

### Tarefa 4: Instalar o Windows Server 2025

Repita para **CMB31-DC01**, **CMB31-SRV01** e **CMB31-ADM01**.

1. Ligue a VM e **ligue-se** a ela (**Connect**). Prima uma tecla quando aparecer *Press any key to boot from CD or DVD*.
1. Idioma e teclado: escolha **Português (Portugal)** ou o seu teclado real. Seleccione **Next > Install now**.
1. Edição:
   - **CMB31-DC01** e **CMB31-ADM01**: `Windows Server 2025 Datacenter Evaluation (Desktop Experience)`
   - **CMB31-SRV01**: `Windows Server 2025 Datacenter Evaluation` (**sem** Desktop Experience = Server Core)
1. Aceite a licença, escolha **Custom: Install Windows only**, seleccione o disco e **Next**.
1. No fim, defina a palavra-passe do `Administrator`: `Pa55w.rd2027!`

> **Porque é que o SRV01 é Server Core?** Menos superfície de ataque, menos actualizações, menos RAM. É assim que a CONTOSO vai correr o File Server. No LAB01 vai aprender a geri-lo sem interface gráfica.

### Tarefa 5: Instalar o Windows 11

Repita para **CMB31-CL01** e **CMB31-CL02**.

1. Arranque pela ISO e instale **Windows 11 Enterprise Evaluation**.
1. No OOBE (configuração inicial), quando pedir rede ou conta Microsoft:
   - Escolha **Set up for work or school**, depois **Sign-in options > Domain join instead**.
   - Crie a conta local `labadmin` com a palavra-passe `Pa55w.rd2027!`.
1. Recuse as opções de privacidade opcionais.

> **Importante para o LAB10:** a CL02 vai ser usada como "portátil novo" que se junta directamente ao Microsoft Entra ID. Depois de a instalar, **desligue-a** e só volte a ligá-la no LAB10.

> **Não encontra a opção "Domain join instead"?** Prima `Shift + F10`, escreva `start ms-cxh:localonly` e prima Enter para criar uma conta local.

### Tarefa 6: Validar a rede e criar o checkpoint

1. Confirme que cada VM arranca até ao ecrã de início de sessão. Ainda **não** terão Internet: o NAT do Hyper-V não distribui endereços por DHCP, por isso os IPs só são configurados no LAB01.
1. Desligue todas as VMs.
1. No PowerShell do portátil:

   ```powershell
   Get-VM -Name 'CMB31-*' | Checkpoint-VM -SnapshotName '00-Instalado'
   ```

---

## Evidência de conclusão

Guarde em `Evidencias\LAB00` uma captura de ecrã ou a saída de:

```powershell
Get-VM -Name 'CMB31-*' | Select-Object Name, State, Generation
Get-VMSnapshot -VMName 'CMB31-*' | Select-Object VMName, Name
Get-NetNat | Select-Object Name, InternalIPInterfaceAddressPrefix
```

## Validação

- [ ] Hyper-V activo no portátil.
- [ ] Switch `CMB31-LAN` e NAT `CMB31-NAT` existem.
- [ ] 5 VMs `CMB31-*` de Geração 2 criadas.
- [ ] DC01 e ADM01 com Desktop Experience; SRV01 em Server Core.
- [ ] CL01 e CL02 com Windows 11 e conta local `labadmin`.
- [ ] Checkpoint `00-Instalado` em todas as VMs.

## Troubleshooting

| Problema | Solução |
|---|---|
| `New-NetNat : Instance MSFT_NetNat already exists` | Já existe outro NAT. `Get-NetNat` para ver; só pode existir um NAT por host Windows. Remova o antigo se não for usado: `Remove-NetNat -Name <nome>`. |
| VM não arranca da ISO ("No operating system was loaded") | Ligue e prima uma tecla rapidamente. Ou em **Settings > Firmware** mova o **DVD Drive** para o topo. |
| Windows 11 "This PC can't run Windows 11" | Falta o TPM: **Settings > Security > Enable Trusted Platform Module**. |
| Portátil fica sem memória | Instale as VMs uma de cada vez e desligue-as no fim. |

## Challenge

Sem consultar o script, escreva o comando PowerShell que cria um **checkpoint só das VMs que estão desligadas**. Dica: `Where-Object State -eq 'Off'`.

## Cleanup

Nada a limpar. **Não elimine as VMs**: são usadas até ao fim do curso.

## Resultado esperado

O "datacenter" da CONTOSO existe no seu portátil: 3 servidores e 2 clientes instalados, numa rede isolada com saída para a Internet, com um checkpoint para voltar atrás a qualquer momento.

**Próximo lab:** [LAB01 - Preparar o Windows Server](LAB_01_Preparar_Windows_Server.md)
