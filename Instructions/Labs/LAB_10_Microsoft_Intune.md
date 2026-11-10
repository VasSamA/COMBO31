---
lab:
    title: 'LAB10 - Microsoft Intune'
    module: 'Domingo 4 - Microsoft 365 Security & Compliance'
---

# LAB10 - Microsoft Intune

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB10 | Microsoft Intune, Microsoft Entra join, BitLocker, Conditional Access | 105 min | 4 |

## O problema

A CONTOSO comprou **portáteis novos para o Financeiro**. Eles vão trabalhar a partir de casa e de clientes, **raramente no escritório**, por isso as GPOs do LAB04 nunca lhes chegam. Um portátil perdido no táxi sem cifra significa todos os ficheiros financeiros nas mãos de quem o encontrar.

Pior: a Helena Matos consegue abrir o e-mail da empresa **em qualquer computador**, incluindo o PC de um cibercafé.

*"Quero gerir os portáteis pela Internet, como gerimos os PCs pelo domínio. E os dados do Financeiro só se abrem em equipamentos da empresa, cifrados e saudáveis."*

## O que este lab resolve

A CONTOSO passa a gerir dispositivos **pela cloud, sem VPN nem domínio**: o portátil do Financeiro (CL02) junta-se ao **Microsoft Entra ID**, inscreve-se automaticamente no **Intune**, recebe **BitLocker**, regras de actualização e uma **política de conformidade**. Uma nova política de **Conditional Access** só deixa o Financeiro aceder ao Microsoft 365 a partir de **dispositivos em conformidade**.

## Objectivos

- Configurar a inscrição automática (MDM user scope).
- Juntar um Windows 11 ao Microsoft Entra ID e inscrevê-lo no Intune.
- Criar uma política de conformidade (compliance policy).
- Aplicar BitLocker (Endpoint security) e um anel de actualizações (update ring).
- Exigir dispositivo em conformidade com Conditional Access.
- Executar acções remotas.

## Pré-requisitos

- [LAB09](LAB_09_MFA_e_Conditional_Access.md) concluído.
- VMs a ligar: **CMB31-DC01** (DHCP/DNS), **CMB31-CL02**. Pode **desligar** CL01, SRV01 e ADM01 para poupar RAM.
- A CL02 tem de ter **TPM activo** (LAB00).
- Utilizador licenciado: `helena.matos@<tenant>` (GG_Financeiro, Business Premium).

## Topologia

```text
CMB31-CL02 (Windows 11, DHCP)
   │  Internet (sem domínio, sem VPN)
   ▼
Microsoft Entra ID (Entra joined) ──▶ Microsoft Intune
                                        ├── Compliance: BitLocker, Secure Boot, Firewall, Defender, SO mínimo
                                        ├── Endpoint security: BitLocker silencioso
                                        └── Update ring: Windows Update for Business
Conditional Access: CA004 - Financeiro só a partir de dispositivo compliant
```

> **Dois modelos de gestão na mesma empresa:** a CL01 representa o **PC do escritório** (domínio + GPO). A CL02 representa o **portátil moderno** (Entra joined + Intune). É exactamente o que se encontra nos clientes reais durante a transição.

## Credenciais

`admin@<tenant>` | `helena.matos@<tenant>` | `abel.chilala@<tenant>` (Vendas, **sem licença**) | conta local da CL02: `labadmin` / `Pa55w.rd2027!`.

---

## Exercício 1: Preparar o Intune

### Tarefa 1: Inscrição automática

1. Abra `https://intune.microsoft.com` como `admin@<tenant>`.
1. **Devices > Enrollment > Windows > Automatic Enrollment** (ou **Entra > Mobility (MDM and WIP) > Microsoft Intune**):
   - **MDM user scope = Some** > grupos `GG_TI`, `GG_Financeiro`, `GG_RH`.
   - **WIP user scope = None**. **Save**.
1. Em `https://entra.microsoft.com` > **Identity > Devices > Device settings**: confirme **Users may join devices to Microsoft Entra = All**.

### Tarefa 2: Grupo de dispositivos

1. **Entra > Groups > New group**:
   - Tipo **Security**, nome `DEV-Windows-Corporativos`, **Membership type = Dynamic Device**.
   - Regra: `(device.deviceOSType -eq "Windows") and (device.managementType -eq "MDM")`.

---

## Exercício 2: Juntar o portátil à cloud

### Tarefa 3: Entra join + inscrição

1. Ligue a **CL02** e entre como `labadmin`. Confirme Internet (recebe IP por DHCP do DC01).
1. **Definições > Contas > Acesso ao trabalho ou escola > Ligar**.
1. **Não** escreva o e-mail no campo principal. Seleccione o link **Associar este dispositivo ao Microsoft Entra ID** (*Join this device to Microsoft Entra ID*).
1. Entre como `helena.matos@<tenant>.onmicrosoft.com` e complete o MFA.
1. Confirme a organização > **Associar** > **Concluído**.
1. **Reinicie** a CL02. No ecrã de início de sessão: **Outro utilizador** > `helena.matos@<tenant>.onmicrosoft.com`.
1. O Windows pede para configurar o **Windows Hello** (PIN). Configure.

### Tarefa 4: Verificar

1. Na CL02, linha de comandos: `dsregcmd /status`. Procure **AzureAdJoined : YES** e, em **Diagnostic Data**, o **MDM URL** do Intune.
1. No Intune: **Devices > Windows**. A CL02 aparece (o nome por omissão é aleatório, tipo `DESKTOP-XXXX`) com **Managed by Intune** e **Primary user = Helena Matos**.

---

## Exercício 3: Políticas

### Tarefa 5: Política de conformidade

1. **Devices > Compliance > Create policy > Windows 10 and later**. Nome `COMP-Windows-CONTOSO`.
1. **Device Health:** *Require BitLocker* = **Require**; *Require Secure Boot* = **Require**.
1. **Device Properties:** *Minimum OS version* = `10.0.22631` (Windows 11 23H2).
1. **System Security:** *Firewall* = **Require**; *Antivirus* = **Require**; *Microsoft Defender Antimalware* = **Require**.
1. **Actions for noncompliance:** *Mark device noncompliant* = **Immediately**.
1. **Assignments:** `GG_Financeiro`. **Create**.

### Tarefa 6: BitLocker silencioso

1. **Endpoint security > Disk encryption > Create policy > Windows > BitLocker**. Nome `ES-BitLocker-CONTOSO`.
1. **BitLocker:** *Require Device Encryption* = **Enabled**; *Allow Warning For Other Disk Encryption* = **Disabled** (necessário para cifra silenciosa); *Allow Standard User Encryption* = **Enabled**.
1. **Operating System Drives:** *Enforce drive encryption type* = **Used Space Only**; *Require Device Encryption* activo; *Choose how BitLocker-protected OS drives can be recovered* = **Enabled**, com **Save BitLocker recovery information to Microsoft Entra ID** e **Do not enable BitLocker until recovery information is stored** activos.
1. **Assignments:** `DEV-Windows-Corporativos`. **Create**.

### Tarefa 7: Anel de actualizações

1. **Devices > Windows updates > Update rings > Create profile**. Nome `UR-Piloto-7dias`.
1. *Quality update deferral* = `7` dias; *Feature update deferral* = `30` dias; *Automatic update behavior* = **Auto install at maintenance time**.
1. **Assignments:** `DEV-Windows-Corporativos`.

### Tarefa 8: Forçar a sincronização e observar

1. Na CL02: **Definições > Contas > Acesso ao trabalho ou escola** > conta da Helena > **Informações > Sincronizar**.
1. Aguarde 10-20 minutos. Entretanto, leia as secções seguintes.
1. No Intune, abra o dispositivo > **Device compliance** e **Device configuration**. Estados possíveis: *Pending*, *Not compliant*, *Compliant*.
1. Na CL02, confirme a cifra: `manage-bde -status C:` (como administrador local `labadmin`, ou via **Definições > Privacidade e segurança > Encriptação do dispositivo**).
1. No Entra: **Devices > All devices** > CL02 > **BitLocker keys**: a chave de recuperação está guardada.

---

## Exercício 4: Só dispositivos em conformidade

### Tarefa 9: CA004

1. Em `https://entra.microsoft.com` > **Conditional Access > New policy** `CA004-Financeiro-Exigir-Dispositivo-Compliant`.
1. **Users:** Include `GG_Financeiro`; Exclude `bg-admin01`.
1. **Target resources:** **Office 365**.
1. **Conditions > Device platforms:** Include **Any device**.
1. **Grant:** **Require device to be marked as compliant**.
1. **Enable policy = Report-only** primeiro. Teste com **What If** e depois mude para **On** quando a CL02 estiver **Compliant**.

### Tarefa 10: Provar

1. Na **CL02** (compliant), abra o Edge (sessão da Helena) e `https://outlook.office.com`: **entra sem problema**.
1. No **seu portátil** (não gerido), numa janela privada, entre como `helena.matos` em `https://outlook.office.com`: aparece **"You can't get there from here"** / acesso bloqueado porque o dispositivo não é gerido.
1. **Sign-in logs:** compare os dois sign-ins, separador **Device info** e **Conditional Access**.

### Tarefa 11: Acções remotas

1. No Intune, abra a CL02 e observe as acções disponíveis: **Sync, Restart, Collect diagnostics, Fresh Start, Wipe, Autopilot Reset, Rotate local admin password, BitLocker key rotation**.
1. Execute **Sync** e **Restart**.

> **Não execute Wipe**: apagaria a VM. Em produção, é a acção a usar quando um portátil é roubado.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB10`:

1. Saída de `dsregcmd /status` (secção Device State).
1. Captura do dispositivo no Intune com **Compliance = Compliant**.
1. Captura da chave BitLocker guardada no Entra (oculte a chave).
1. Captura do bloqueio no portátil não gerido e do sucesso na CL02.

## Validação

- [ ] CL02 Entra joined e inscrita no Intune com a Helena como utilizadora principal.
- [ ] BitLocker activo e chave guardada no Entra.
- [ ] Política de conformidade atribuída; dispositivo **Compliant**.
- [ ] Anel de actualizações atribuído.
- [ ] CA004 activa: Financeiro bloqueado em dispositivos não geridos.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| Junção falha: *"Your organization requires MFA"* sem conseguir completar | Helena sem MFA registado | Registe em `aka.ms/mysecurityinfo` (LAB09). |
| Dispositivo Entra joined mas **não** aparece no Intune | Utilizador fora do MDM user scope ou sem licença | Helena tem de estar em GG_Financeiro **e** licenciada. Desassocie, corrija e associe de novo. |
| BitLocker não liga | VM sem TPM | Desligue a CL02 > **Settings > Security > Enable Trusted Platform Module**. |
| Fica **Not compliant** por Secure Boot | Secure Boot desligado na VM | **Settings > Security > Enable Secure Boot** (template Microsoft Windows). |
| Políticas demoram | Ciclo normal do Intune | Sincronize na CL02 e no portal; aguarde até 30 min. |
| Fiquei sem acesso ao Office no portátil pessoal como admin | CA004 só abrange GG_Financeiro | Confirme que não incluiu "All users". |

## Challenge

1. Crie um **perfil de configuração** (Settings catalog) que defina a página inicial do Edge como `https://www.office.com` e bloqueie o acesso ao **Painel de Controlo** apenas aos dispositivos `DEV-Windows-Corporativos`. Compare com a GPO do LAB04: o que é igual e o que muda?
1. Active o **Windows LAPS gerido pelo Intune** (**Endpoint security > Account protection > Local admin password solution**) com cópia para o Entra ID e leia a palavra-passe da CL02 no portal.

## Cleanup

Nada a apagar. Mantenha a CL02 inscrita: é usada no LAB11.

## Resultado esperado

O portátil do Financeiro é gerido de qualquer lugar, cifrado, actualizado e verificado continuamente. Os dados da CONTOSO só se abrem em equipamentos da CONTOSO.

**Próximo lab:** [LAB11 - Microsoft Defender](LAB_11_Microsoft_Defender.md)
