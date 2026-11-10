---
lab:
    title: 'LAB05 - File Server e permissões'
    module: 'Domingo 2 - Windows Server Administration & Security'
---

# LAB05 - File Server e permissões

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB05 | Hyper-V, Storage, File Server, NTFS, SMB, Group Policy Preferences, Shadow Copies | 105 min | 2 |

## O problema

Na CONTOSO os ficheiros andam por todo o lado: o mapa salarial está numa pen USB do RH, as facturas do Financeiro circulam por e-mail e o Marketing guarda campanhas no ambiente de trabalho. A semana passada, um estagiário de Vendas abriu por engano uma pasta com os salários de toda a empresa, porque estava partilhada com "Everyone".

Quando alguém apaga um ficheiro por engano, não há forma de o recuperar.

## O que este lab resolve

A CONTOSO passa a ter um **File Server central** (`\\CMB31-SRV01`) com uma pasta por departamento, **permissões baseadas em grupos** (modelo AGDLP), **Access-Based Enumeration** (cada pessoa só vê as pastas a que tem acesso), **unidades de rede mapeadas automaticamente** por GPO, e **Shadow Copies** para que o próprio utilizador recupere versões anteriores de um ficheiro.

## Objectivos

- Adicionar um disco a uma VM em funcionamento (Hyper-V) e prepará-lo remotamente.
- Instalar a role File Server num **Server Core** a partir do ADM01.
- Aplicar o modelo **AGDLP** com permissões NTFS e de partilha.
- Activar Access-Based Enumeration.
- Mapear unidades com **Group Policy Preferences** e *item-level targeting*.
- Configurar e usar **Shadow Copies (Previous Versions)**.

## Pré-requisitos

- [LAB03](LAB_03_Estruturar_a_CONTOSO.md) concluído ([LAB04](LAB_04_Group_Policy.md) recomendado).
- VMs a ligar: **CMB31-DC01, CMB31-SRV01, CMB31-ADM01, CMB31-CL01**.

## Topologia

```text
\\CMB31-SRV01 (Server Core)
  E:\ (disco "Dados", 40 GB)
  └── Shares
      ├── Comum        -> todos (GG_Todos) leitura/escrita
      ├── Financeiro   -> GG_Financeiro (Modify), GG_Direccao (Read)
      ├── RH           -> GG_RH (Modify), GG_Direccao (Read)
      ├── Marketing    -> GG_Marketing (Modify)
      └── Vendas       -> GG_Vendas (Modify), GG_Marketing (Read)
```

**Modelo AGDLP:** **A**ccounts > **G**lobal groups (`GG_*`, por função) > **D**omain **L**ocal groups (`DL_FS_*`, por recurso e permissão) > **P**ermissions. As permissões NTFS só são dadas a grupos `DL_`. Quando um colaborador muda de departamento, muda-se **um** grupo; as permissões não são tocadas.

## Credenciais

`CONTOSO\Administrator` / `Pa55w.rd2027!`. Testes: `helena.matos` (Directora Financeira), `adilson.cassoma` (Financeiro), `patricia.lunda` (Marketing), `abel.chilala` (Vendas) / `Contoso#2027`.

---

## Exercício 1: Disco e role File Server

### Tarefa 1: Adicionar um disco ao SRV01 sem o desligar (Hyper-V)

1. No **portátil (host)**, PowerShell como Administrador (ajuste o caminho):

   ```powershell
   $vhd = 'D:\Hyper-V\CMB31\CMB31-SRV01\CMB31-SRV01-Dados.vhdx'
   New-VHD -Path $vhd -SizeBytes 40GB -Dynamic
   Add-VMHardDiskDrive -VMName CMB31-SRV01 -ControllerType SCSI -Path $vhd
   ```

> Em VMs de **Geração 2**, discos SCSI podem ser adicionados **a quente** (com a VM ligada). É assim que se aumenta capacidade sem paragem.

### Tarefa 2: Inicializar e formatar remotamente

1. No **ADM01**, PowerShell como Administrador:

   ```powershell
   $s = New-CimSession -ComputerName CMB31-SRV01
   Get-Disk -CimSession $s | Where-Object PartitionStyle -eq 'RAW'
   Get-Disk -CimSession $s | Where-Object PartitionStyle -eq 'RAW' |
       Initialize-Disk -PartitionStyle GPT -PassThru |
       New-Partition -DriveLetter E -UseMaximumSize |
       Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Dados' -Confirm:$false
   Get-Volume -CimSession $s -DriveLetter E
   ```

   Alternativa visual: **Windows Admin Center > CMB31-SRV01 > Storage**.

### Tarefa 3: Instalar a role File Server

1. No ADM01:

   ```powershell
   Install-WindowsFeature -ComputerName CMB31-SRV01 -Name FS-FileServer, FS-Resource-Manager -IncludeManagementTools
   Install-WindowsFeature -Name RSAT-File-Services    # consolas no ADM01
   ```

---

## Exercício 2: Grupos, pastas e permissões

### Tarefa 4: Criar os grupos Domain Local (AGDLP)

1. No ADM01:

   ```powershell
   $ou = 'OU=Grupos,OU=_CONTOSO,DC=corp,DC=contoso,DC=com'
   $map = @{
     'DL_FS_Comum_RW'      = 'GG_Todos'
     'DL_FS_Financeiro_RW' = 'GG_Financeiro'; 'DL_FS_Financeiro_RO' = 'GG_Direccao'
     'DL_FS_RH_RW'         = 'GG_RH';         'DL_FS_RH_RO'         = 'GG_Direccao'
     'DL_FS_Marketing_RW'  = 'GG_Marketing'
     'DL_FS_Vendas_RW'     = 'GG_Vendas';     'DL_FS_Vendas_RO'     = 'GG_Marketing'
   }
   foreach ($dl in $map.Keys) {
       New-ADGroup -Name $dl -GroupScope DomainLocal -GroupCategory Security -Path $ou
       Add-ADGroupMember -Identity $dl -Members $map[$dl]
   }
   Get-ADGroup -Filter "Name -like 'DL_FS_*'" | Select-Object Name, GroupScope
   ```

### Tarefa 5: Criar as pastas e as permissões NTFS

1. Ainda no ADM01, execute **no SRV01**:

   ```powershell
   Invoke-Command -ComputerName CMB31-SRV01 -ScriptBlock {
       $base = 'E:\Shares'
       $acl = @{
         'Comum'      = @(@('DL_FS_Comum_RW','Modify'))
         'Financeiro' = @(@('DL_FS_Financeiro_RW','Modify'), @('DL_FS_Financeiro_RO','ReadAndExecute'))
         'RH'         = @(@('DL_FS_RH_RW','Modify'),         @('DL_FS_RH_RO','ReadAndExecute'))
         'Marketing'  = @(@('DL_FS_Marketing_RW','Modify'))
         'Vendas'     = @(@('DL_FS_Vendas_RW','Modify'),     @('DL_FS_Vendas_RO','ReadAndExecute'))
       }
       foreach ($folder in $acl.Keys) {
           $path = Join-Path $base $folder
           New-Item -ItemType Directory -Path $path -Force | Out-Null
           # Cortar a herança e começar de uma ACL limpa
           icacls $path /inheritance:r /grant:r 'CONTOSO\Domain Admins:(OI)(CI)F' 'SYSTEM:(OI)(CI)F' | Out-Null
           foreach ($entry in $acl[$folder]) {
               $perm = if ($entry[1] -eq 'Modify') { 'M' } else { 'RX' }
               icacls $path /grant "CONTOSO\$($entry[0]):(OI)(CI)$perm" | Out-Null
           }
       }
       icacls E:\Shares\Financeiro
   }
   ```

1. Leia a saída do `icacls` da pasta Financeiro: não existe **Users** nem **Everyone**. Só administradores, SYSTEM e os dois grupos `DL_FS_Financeiro_*`.

### Tarefa 6: Criar as partilhas com Access-Based Enumeration

> **Boa prática:** permissões de **partilha** largas (Authenticated Users: Change) e permissões **NTFS** restritas. A permissão efectiva é a **mais restritiva das duas**; controlar num só sítio (NTFS) evita confusão.

1. No ADM01:

   ```powershell
   Invoke-Command -ComputerName CMB31-SRV01 -ScriptBlock {
       foreach ($f in 'Comum','Financeiro','RH','Marketing','Vendas') {
           New-SmbShare -Name $f -Path "E:\Shares\$f" `
               -FullAccess 'CONTOSO\Domain Admins' -ChangeAccess 'NT AUTHORITY\Authenticated Users' `
               -FolderEnumerationMode AccessBased -CachingMode None
       }
       Get-SmbShare | Where-Object Path -like 'E:\Shares\*' | Select-Object Name, FolderEnumerationMode
   }
   ```

---

## Exercício 3: Mapear unidades com Group Policy Preferences

### Tarefa 7: GPO de mapeamentos

1. Em **GPMC**, na OU **_CONTOSO > Utilizadores**, crie e ligue `GPO-CONTOSO-Mapeamentos`.
1. **Edit** > **User Configuration > Preferences > Windows Settings > Drive Maps** > **New > Mapped Drive**:

   | Letra | Localização | Etiqueta | Item-level targeting |
   |---|---|---|---|
   | `S:` | `\\CMB31-SRV01\Comum` | Comum | nenhum (todos) |
   | `F:` | `\\CMB31-SRV01\Financeiro` | Financeiro | Security Group = `CONTOSO\GG_Financeiro` **ou** `CONTOSO\GG_Direccao` |
   | `R:` | `\\CMB31-SRV01\RH` | RH | Security Group = `CONTOSO\GG_RH` **ou** `CONTOSO\GG_Direccao` |
   | `M:` | `\\CMB31-SRV01\Marketing` | Marketing | Security Group = `CONTOSO\GG_Marketing` |
   | `V:` | `\\CMB31-SRV01\Vendas` | Vendas | Security Group = `CONTOSO\GG_Vendas` **ou** `CONTOSO\GG_Marketing` |

   Para cada mapeamento: **Action = Update**, **Reconnect** marcado. Em **Common > Item-level targeting > Targeting... > New Item > Security Group**. Para "ou", adicione o segundo grupo e mude o operador para **OR**.

### Tarefa 8: Testar como utilizadores diferentes

1. Na **CL01**, entre como `CONTOSO\adilson.cassoma` (Financeiro). Abra o **Explorador de Ficheiros**:
   - Deve ver `S:` e `F:`.
   - Crie `F:\Facturas_2027.txt`. Funciona.
1. Entre como `CONTOSO\patricia.lunda` (Marketing):
   - Deve ver `S:`, `M:` e `V:`. Tente criar um ficheiro em `V:`: **acesso negado** (só leitura).
   - Escreva `\\CMB31-SRV01` na barra de endereço. **A pasta Financeiro nem aparece** (Access-Based Enumeration).
1. Entre como `CONTOSO\helena.matos` (Directora Financeira, membro de GG_Financeiro e GG_Direccao): vê `F:` com escrita **e** `R:` só leitura.

### Tarefa 9: Effective Access

1. No ADM01, abra `\\CMB31-SRV01\E$\Shares\RH` > **Properties > Security > Advanced > Effective Access**.
1. **Select a user** > `abel.chilala` > **View effective access**. Tudo negado.
1. Repita com `helena.matos`: só leitura.

---

## Exercício 4: Recuperar ficheiros apagados (Shadow Copies)

### Tarefa 10: Activar Shadow Copies no volume E:

1. No ADM01 abra **Computer Management** > botão direito em **Computer Management (Local)** > **Connect to another computer** > `CMB31-SRV01`.
1. **System Tools > Shared Folders** > botão direito > **All Tasks > Configure Shadow Copies**.
1. Seleccione **E:\** > **Enable** > **Create Now**. Observe o agendamento por omissão (07h00 e 12h00 em dias úteis).

   Para criar uma shadow copy a pedido pela linha de comandos (útil no Server Core):

   ```powershell
   Invoke-Command -ComputerName CMB31-SRV01 -ScriptBlock { vssadmin create shadow /for=E: ; vssadmin list shadows /for=E: }
   ```

### Tarefa 11: O utilizador recupera sozinho

1. Na CL01, como `adilson.cassoma`, abra `F:\Facturas_2027.txt`, escreva uma linha e grave.
1. No ADM01, crie outra shadow copy (**Create Now**).
1. Na CL01, **apague** o ficheiro `Facturas_2027.txt`.
1. Botão direito na pasta `F:\` > **Properties > Previous Versions** > abra a versão mais recente > copie o ficheiro de volta.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB05`:

1. Saída do `icacls E:\Shares\Financeiro`.
1. Captura do Explorador da Patrícia (Marketing) em `\\CMB31-SRV01` **sem** a pasta Financeiro.
1. Captura do **Effective Access** de `helena.matos` na pasta RH.
1. Captura do separador **Previous Versions** com a versão restaurada.

## Validação

- [ ] Disco E: "Dados" no SRV01, adicionado a quente.
- [ ] 5 partilhas com ABE activo.
- [ ] Permissões NTFS só com grupos `DL_FS_*` (e administradores/SYSTEM).
- [ ] Unidades mapeadas automaticamente conforme o departamento.
- [ ] Marketing lê Vendas mas não escreve; não vê Financeiro.
- [ ] Ficheiro apagado recuperado por Previous Versions.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| Unidade não aparece | GPP não aplicada ou utilizador não está no grupo | `gpupdate /force`, terminar sessão e voltar a entrar (a pertença a grupos só é lida no login). |
| "Access is denied" quando devia ter acesso | Token antigo após adicionar ao grupo | Terminar sessão e entrar de novo. `whoami /groups`. |
| `New-SmbShare`: *"The name has already been shared"* | Já executou o comando | `Get-SmbShare` e continue. |
| `Get-Disk` não mostra o disco novo | Disco ainda não detectado | `Update-HostStorageCache -CimSession $s`. |
| Sem "Previous Versions" | Shadow Copies não activas ou nenhuma criada após a alteração | Tarefa 10, **Create Now**. |

## Challenge

Com o **File Server Resource Manager** (já instalado), impeça que alguém grave ficheiros de vídeo e música (`*.mp4`, `*.mp3`) na partilha **Comum** e crie uma **quota de 5 GB** na pasta Marketing com aviso aos 80%. Use os cmdlets `New-FsrmFileScreen` e `New-FsrmQuota` (via `Invoke-Command`).

## Cleanup

Nada a limpar. O File Server é reutilizado no LAB06, LAB15 (migração de arquivo morto para o Azure) e no LAB16 (Azure Arc).

## Resultado esperado

Cada departamento tem o seu espaço, cada pessoa vê apenas o que lhe compete, os mapeamentos aparecem sozinhos e os utilizadores recuperam os próprios erros sem abrir um pedido ao Suporte.

**Próximo lab:** [LAB06 - Operações e troubleshooting](LAB_06_Operacoes_e_Troubleshooting.md)
