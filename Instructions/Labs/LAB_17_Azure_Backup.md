---
lab:
    title: 'LAB17 - Azure Backup'
    module: 'Domingo 6 - Azure Operations'
---

# LAB17 - Azure Backup

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB17 | Recovery Services vault, backup policy, backup de VM, File Recovery, soft delete | 105 min | 6 |

## O problema

Uma empresa vizinha da CONTOSO foi atingida por **ransomware**: servidores cifrados **e** as cópias de segurança também, porque estavam numa partilha de rede no mesmo edifício. Perderam 3 semanas de facturação.

O backup que a CONTOSO fez no LAB06 tem exactamente esse problema: **está no mesmo escritório** e qualquer administrador o pode apagar. E a nova VM da aplicação no Azure **não tem backup nenhum**.

*"Quero cópias fora do edifício, que nem um administrador comprometido consiga apagar de imediato, e quero ver um restauro a funcionar antes de acreditar."*

## O que este lab resolve

A VM da aplicação da CONTOSO passa a ter **backup diário automático** num **Recovery Services vault**, com retenção definida, **protecção contra eliminação (soft delete)** e um **restauro de ficheiro testado**. A equipa percebe também como a governance do LAB13 interage com serviços que criam recursos automaticamente.

## Objectivos

- Criar um Recovery Services vault e definir a redundância **antes** de proteger.
- Criar uma backup policy e preparar o RG de instant restore (compatível com as policies do LAB13).
- Activar e executar o backup de uma VM.
- Recuperar um ficheiro apagado com **File Recovery**.
- Compreender e testar o soft delete.
- Executar o Cleanup correcto de um vault.

## Pré-requisitos

- [LAB14](LAB_14_VNet_e_VM.md) concluído (`vm-contoso-app01` com saída via NAT Gateway).
- Cloud Shell com `$ini`, `$loc`, `$tags`.

> **Tempo:** o primeiro backup pode demorar **30-90 minutos**. Faça as Tarefas 1-5 primeiro, avance para o [LAB18](LAB_18_Seguranca_e_Automacao.md) enquanto o backup corre e volte para o Exercício 3.

## Topologia

```text
rg-contoso-ops-<ini>
└── rsv-contoso-<ini> (Recovery Services vault, LRS, soft delete 14 dias)
    └── policy: pol-vm-diaria-<ini>  (21:00, 7 diários, 4 semanais)
         └── protege: vm-contoso-app01 (rg-contoso-app-<ini>)
               └── snapshots instant restore: rg-contoso-bkp-<ini>-1
```

## Credenciais

`admin@<tenant>` | `azureadmin` (VM).

---

## Exercício 1: Preparar

### Tarefa 1: Dados de negócio na VM

1. Inicie a `vm-contoso-app01` e ligue-se via **Bastion**. PowerShell:

   ```powershell
   New-Item C:\Dados -ItemType Directory -Force | Out-Null
   1..5 | ForEach-Object { Set-Content "C:\Dados\Contrato_Cliente_$_.txt" "Contrato fictício n.º $_ - CONTOSO Angola - $(Get-Date)" }
   Get-ChildItem C:\Dados
   ```

### Tarefa 2: Criar o vault

1. No Cloud Shell:

   ```powershell
   $vault = New-AzRecoveryServicesVault -Name "rsv-contoso-$ini" -ResourceGroupName "rg-contoso-ops-$ini" -Location $loc -Tag $tags
   Set-AzRecoveryServicesBackupProperty -Vault $vault -BackupStorageRedundancy LocallyRedundant
   ```

> **Redundância primeiro.** A redundância do armazenamento do vault (LRS, ZRS, GRS) **só pode ser alterada antes** de proteger o primeiro item. Por omissão é **GRS** (mais caro). Em produção, a CONTOSO escolheria GRS para ter cópia noutra região; em laboratório usamos LRS.

1. Portal > `rsv-contoso-<ini>` > **Settings > Properties > Security settings**: confirme **Soft delete** activo (14 dias). **Não** active a opção *always-on* (tornaria o soft delete irreversível e impediria o Cleanup rápido no fim do lab).

### Tarefa 3: RG de instant restore (governance a funcionar)

O Azure Backup guarda **snapshots** dos discos num Resource Group próprio. Por omissão cria-o automaticamente (`AzureBackupRG_...`) **sem tags**, e a policy *Require a tag on resource groups* do LAB13 **bloquearia** essa criação, fazendo o backup falhar. A solução profissional: **criar o RG com as tags e dizer ao Backup para o usar**.

1. No Cloud Shell:

   ```powershell
   New-AzResourceGroup -Name "rg-contoso-bkp-$ini-1" -Location $loc -Tag $tags
   ```

### Tarefa 4: Backup policy

1. Portal > `rsv-contoso-<ini>` > **Manage > Backup policies > + Add > Azure Virtual Machine**.
1. **Policy sub type:** **Standard** (um backup por dia). *(Enhanced permite vários por dia, mas é mais caro.)*
1. Nome `pol-vm-diaria-<ini>`.
1. **Backup schedule:** Daily, **21:00**, fuso **(UTC+01:00) West Central Africa**.
1. **Instant restore:** retenção de snapshots **2** dias. Em **Azure Backup Resource Group**, indique o prefixo `rg-contoso-bkp-<ini>-` (o Azure Backup acrescenta o número `1`, coincidindo com o RG da Tarefa 3).
1. **Retention range:** diários **7** dias; semanais (domingo) **4** semanas. Desactive mensais e anuais.
1. **Create**.

---

## Exercício 2: Proteger a VM

### Tarefa 5: Activar e executar o backup

1. `rsv-contoso-<ini>` > **Getting started > Backup** > *Where is your workload running?* **Azure** > *What do you want to back up?* **Virtual machine** > **Backup**.
1. **Policy:** `pol-vm-diaria-<ini>`. **Virtual machines > Add** > `vm-contoso-app01` > **OK > Enable backup**.
1. Após a activação: **Protected items > Backup items > Azure Virtual Machine** > `vm-contoso-app01` > **Backup now** > retenção até daqui a **7 dias** > **OK**.
1. **Monitoring > Backup jobs:** acompanhe. Fases: *Take Snapshot* (minutos) e *Transfer data to vault* (mais demorado).

> O snapshot já permite restaurar (**instant restore**) assim que a primeira fase termina. Avance para o LAB18 e volte quando o job estiver **Completed** (ou pelo menos com a fase de snapshot concluída).

---

## Exercício 3: O desastre e o restauro

### Tarefa 6: Simular a perda

1. Na VM (Bastion), simule um ataque que destrói os contratos:

   ```powershell
   Remove-Item C:\Dados\* -Force
   Get-ChildItem C:\Dados    # vazio
   ```

### Tarefa 7: File Recovery

1. Portal > `vm-contoso-app01` > **Operations > Backup > File Recovery**.
1. **Select recovery point:** o mais recente.
1. **Download Executable** e copie a **palavra-passe** mostrada.
1. Na VM, o download pode ser feito directamente no Edge da VM (sessão Bastion): abra o portal **dentro da VM** e repita os passos 1-3, ou transfira o ficheiro com a área de transferência do Bastion.
1. Execute o ficheiro descarregado **como administrador** e introduza a palavra-passe. O script monta o ponto de recuperação como **novas unidades** (ex.: `F:`, `G:`).
1. Copie os contratos de volta:

   ```powershell
   Get-PSDrive -PSProvider FileSystem     # identifique a unidade que contém \Dados
   Copy-Item F:\Dados\* C:\Dados\     # substitua F: pela unidade montada que contém \Dados
   Get-ChildItem C:\Dados
   ```

1. No portal, **Unmount Disks** para terminar a sessão de recuperação.

> **File Recovery vs restaurar a VM inteira:** para meia dúzia de ficheiros, montar o ponto de recuperação é muito mais rápido. Para uma VM destruída, usa-se **Restore VM** (criar nova VM ou substituir discos).

### Tarefa 8: Soft delete (o administrador comprometido)

1. **Backup items > vm-contoso-app01 > Stop backup > Delete backup data**. Escreva o nome e um motivo. **Stop backup**.
1. A VM aparece em **Backup items** com estado **Soft deleted**: os dados **não foram apagados**. Durante 14 dias ninguém os pode eliminar definitivamente.
1. Recupere: **... > Undelete**. Depois **Resume backup** com a mesma policy.

> É isto que protege a CONTOSO do cenário da empresa vizinha: mesmo um atacante com credenciais de administrador **não consegue destruir os backups imediatamente**.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB17`:

1. Captura da backup policy.
1. Captura do **Backup job** com estado **Completed**.
1. `Get-ChildItem C:\Dados` **antes** (vazio) e **depois** do File Recovery.
1. Captura do item em **Soft deleted** e depois recuperado.

## Validação

- [ ] Vault com LRS definido antes de proteger.
- [ ] RG de instant restore criado com tags (compatível com a governance do LAB13).
- [ ] Backup diário activo na `vm-contoso-app01`.
- [ ] Ficheiros apagados recuperados com File Recovery.
- [ ] Soft delete testado: eliminação revertida.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| Activação do backup falha com `RequestDisallowedByPolicy` | O Backup tentou criar `AzureBackupRG_...` sem tags | Tarefas 3 e 4: RG pré-criado e prefixo na policy. |
| Job falha com erro de extensão (`UserErrorGuestAgentStatusUnavailable`) | VM parada ou sem saída | Inicie a VM; confirme o NAT Gateway; aguarde o VM Agent ficar *Ready*. |
| Não consigo mudar a redundância | Já existe um item protegido | Só antes do primeiro backup. |
| Script de File Recovery não monta discos | Executado sem privilégios ou sem saída HTTPS | Execute como administrador; a VM precisa de saída para a Internet (porta 443). |
| Não consigo eliminar o vault | Itens protegidos ou soft-deleted | Siga o Cleanup abaixo **pela ordem**. |

## Challenge

1. Faça um **Restore VM > Create new virtual machine** para uma VM `vm-contoso-rst01` na mesma subnet, confirme que `C:\Dados` existe nela e **elimine-a** em seguida (VM, disco e NIC).
1. No ADM01 (on-premises), instale o **agente MARS** (Microsoft Azure Recovery Services) e faça backup de uma pasta local para o mesmo vault. Explique porque é que este backup resolve o problema do LAB06.

## Cleanup

> **Faça este Cleanup no fim do Domingo 6**, depois do LAB18. Se continuar o curso noutro dia, pode manter o backup activo (custo baixo para uma VM).

Ordem obrigatória para conseguir apagar o vault:

1. `rsv-contoso-<ini>` > **Properties > Security settings > Soft delete** > **desactivar** (só possível se não activou o *always-on*).
1. **Backup items > vm-contoso-app01 > Stop backup > Delete backup data**.
1. Se o item ficou em *Soft deleted* (porque o soft delete ainda estava activo), **Undelete** e repita o passo 2.
1. Elimine o vault: `Remove-AzRecoveryServicesVault -Vault (Get-AzRecoveryServicesVault -Name "rsv-contoso-$ini")`.
1. Elimine o RG de snapshots: `Remove-AzResourceGroup -Name "rg-contoso-bkp-$ini-1" -Force`.

## Resultado esperado

A aplicação da CONTOSO tem cópias diárias fora do escritório, protegidas contra eliminação maliciosa, e a equipa **já provou** que consegue restaurar.

**Próximo lab:** [LAB18 - Segurança, Updates e automação](LAB_18_Seguranca_e_Automacao.md)
