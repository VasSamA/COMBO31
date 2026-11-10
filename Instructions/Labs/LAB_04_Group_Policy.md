---
lab:
    title: 'LAB04 - Group Policy'
    module: 'Domingo 2 - Windows Server Administration & Security'
---

# LAB04 - Group Policy

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB04 | Group Policy, Windows LAPS | 105 min | 2 |

## O problema

Uma auditoria interna à CONTOSO encontrou:

- Postos de trabalho que **nunca bloqueiam o ecrã**: um vendedor deixou o PC aberto com o sistema de facturação durante o almoço.
- Palavras-passe de 6 caracteres e **sem bloqueio** após tentativas falhadas.
- Utilizadores do **Marketing** a alterar definições de rede e a instalar impressoras pelo Painel de Controlo, gerando chamadas para o Suporte todas as semanas.
- **A mesma palavra-passe de administrador local em todos os PCs.** Se um PC for comprometido, todos estão.

Configurar isto PC a PC é impossível de manter. A CONTOSO precisa de **regras centrais aplicadas automaticamente**.

## O que este lab resolve

A CONTOSO passa a ter **políticas de segurança e configuração aplicadas centralmente** a partir do AD: palavra-passe e bloqueio de conta no domínio, bloqueio de ecrã e aviso legal em todos os postos, restrições apenas ao Marketing, e uma **palavra-passe de administrador local única e rotativa em cada PC (Windows LAPS)**. O administrador sabe também **diagnosticar** porque é que uma política se aplica ou não.

## Objectivos

- Configurar a política de palavras-passe e bloqueio de conta do domínio.
- Criar, ligar e filtrar GPOs de computador e de utilizador.
- Compreender e demonstrar herança, precedência, **Block Inheritance** e **Enforced**.
- Diagnosticar com `gpresult` e **Group Policy Results**.
- Implementar Windows LAPS.

## Pré-requisitos

- [LAB03](LAB_03_Estruturar_a_CONTOSO.md) concluído.
- VMs a ligar: **CMB31-DC01, CMB31-ADM01, CMB31-CL01**.
- Script: `Allfiles/Labs/04/Test-ContosoGpo.ps1` (copiar para `C:\Labfiles\04` na CL01).

## Topologia: GPOs a criar

| GPO | Ligada a | Tipo | Configuração |
|---|---|---|---|
| Default Domain Policy | `corp.contoso.com` | Computador | Palavras-passe e bloqueio de conta |
| `GPO-CONTOSO-Postos-Seguranca` | `_CONTOSO\Computadores\Postos` | Computador | Bloqueio 10 min, aviso legal, firewall |
| `GPO-CONTOSO-Marketing-Restricoes` | `_CONTOSO\Utilizadores\Marketing` | Utilizador | Bloquear Painel de Controlo e Definições |
| `GPO-CONTOSO-LAPS` | `_CONTOSO\Computadores` | Computador | Windows LAPS com cópia no AD |

**Ordem de processamento (LSDOU):** Local > Site > Domínio > OU pai > OU filha. Em caso de conflito, **a última a aplicar ganha**, salvo se uma GPO acima estiver **Enforced**.

## Credenciais

`CONTOSO\Administrator` / `Pa55w.rd2027!` | `CONTOSO\patricia.lunda` (Marketing) e `CONTOSO\abel.chilala` (Vendas) / `Contoso#2027`.

---

## Exercício 1: Política de palavras-passe do domínio

### Tarefa 1: Ver a política actual

1. No **ADM01**, PowerShell:

   ```powershell
   Get-ADDefaultDomainPasswordPolicy
   ```

   Anote `MinPasswordLength` e `LockoutThreshold` (por omissão: 7 e 0 = nunca bloqueia).

### Tarefa 2: Editar a Default Domain Policy

> A política de palavras-passe **dos utilizadores do domínio** só tem efeito numa GPO ligada **à raiz do domínio**. Ligada a uma OU, afecta apenas as contas locais dos computadores dessa OU.

1. Abra **Group Policy Management** (`gpmc.msc`) > **Forest > Domains > corp.contoso.com**.
1. Botão direito em **Default Domain Policy > Edit**.
1. **Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies**:
   - **Password Policy**: *Minimum password length* = `12`; *Maximum password age* = `180` dias.
   - **Account Lockout Policy**: *Account lockout threshold* = `10`; aceite os valores sugeridos de 10 minutos e altere ambos para `15` minutos.
1. Feche o editor e confirme:

   ```powershell
   Get-ADDefaultDomainPasswordPolicy | Select-Object MinPasswordLength, LockoutThreshold, LockoutDuration
   ```

> **Porquê 12 caracteres e não "complexidade máxima"?** As recomendações actuais (NIST, Microsoft) privilegiam o **comprimento** e a protecção contra palavras-passe conhecidas, em vez de regras de complexidade e expiração frequente. No Domingo 3 a CONTOSO dá o salto real com MFA.

---

## Exercício 2: GPOs de computador e de utilizador

### Tarefa 3: GPO de segurança dos postos

1. Em GPMC, botão direito na OU **_CONTOSO > Computadores > Postos** > **Create a GPO in this domain, and Link it here** > `GPO-CONTOSO-Postos-Seguranca`.
1. **Edit** e configure em **Computer Configuration > Policies > Windows Settings > Security Settings > Local Policies > Security Options**:
   - *Interactive logon: Machine inactivity limit* = `600` segundos.
   - *Interactive logon: Message title for users attempting to log on* = `CONTOSO Angola - Aviso`.
   - *Interactive logon: Message text for users attempting to log on* = `Este sistema é para uso exclusivo de colaboradores autorizados da CONTOSO. A actividade pode ser monitorizada.`
1. Em **Computer Configuration > Policies > Windows Settings > Security Settings > Windows Defender Firewall with Advanced Security**, abra as propriedades e defina **Firewall state: On** nos perfis **Domain, Private e Public**.

### Tarefa 4: GPO só para o Marketing

1. Botão direito na OU **_CONTOSO > Utilizadores > Marketing** > **Create a GPO...** > `GPO-CONTOSO-Marketing-Restricoes`.
1. **Edit** > **User Configuration > Policies > Administrative Templates > Control Panel**:
   - *Prohibit access to Control Panel and PC settings* = **Enabled**.
1. Feche o editor.

### Tarefa 5: Aplicar e verificar na CL01

1. Na **CL01**, inicie sessão como `CONTOSO\patricia.lunda`. Repare no **aviso legal** antes do login.
1. Abra a linha de comandos:

   ```cmd
   gpupdate /force
   gpresult /r
   ```

   Em **COMPUTER SETTINGS** deve aparecer `GPO-CONTOSO-Postos-Seguranca`; em **USER SETTINGS**, `GPO-CONTOSO-Marketing-Restricoes`.

1. Tente abrir o **Painel de Controlo** e as **Definições**: devem estar bloqueados.
1. Termine a sessão e entre como `CONTOSO\abel.chilala` (Vendas). O Painel de Controlo funciona: a GPO só se aplica à OU do Marketing.
1. Execute o script de verificação:

   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Labfiles\04\Test-ContosoGpo.ps1
   ```

   Neste momento a linha **Windows LAPS** deve dar `FALHA`. Vai corrigi-la no Exercício 4.

---

## Exercício 3: Herança, precedência e diagnóstico

### Tarefa 6: Provocar um conflito

O Director de TI pediu que **os postos do TI** não bloqueiem aos 10 minutos mas aos 30 (os técnicos correm tarefas longas). Ao mesmo tempo, a Direcção quer garantir que **ninguém** desliga a firewall.

1. Crie a OU `_CONTOSO\Computadores\Postos\TI` e, nela, a GPO ligada `GPO-CONTOSO-Postos-TI` com *Machine inactivity limit* = `1800`.
1. Em GPMC, seleccione a OU **TI** e abra o separador **Group Policy Inheritance**. Veja a ordem: a GPO da OU filha tem **precedência 1** e ganha o conflito.
1. Agora simule um erro: botão direito na OU **TI** > **Block Inheritance**. Volte ao separador **Group Policy Inheritance**: `GPO-CONTOSO-Postos-Seguranca` desapareceu. A firewall deixou de ser garantida para esta OU.
1. Corrija com **Enforced**: em **Postos**, botão direito na ligação `GPO-CONTOSO-Postos-Seguranca` > **Enforced**. Volte à OU TI: a GPO reaparece, mesmo com Block Inheritance, e **agora ganha** o conflito do bloqueio de ecrã (600 s).

> **Pergunta para reflectir:** o Enforced resolveu a firewall mas desfez o pedido do TI (30 min). Qual seria um desenho melhor? (Resposta no Challenge.)

1. Retire o **Enforced** e o **Block Inheritance** antes de continuar.

### Tarefa 7: Group Policy Results e Modeling

1. Mova a CL01 para a OU `Postos\TI`:

   ```powershell
   Get-ADComputer CMB31-CL01 | Move-ADObject -TargetPath 'OU=TI,OU=Postos,OU=Computadores,OU=_CONTOSO,DC=corp,DC=contoso,DC=com'
   ```

1. Na CL01: `gpupdate /force`.
1. Em GPMC, botão direito em **Group Policy Results** > **Group Policy Results Wizard** > computador `CMB31-CL01`, utilizador `CONTOSO\patricia.lunda`.
1. No relatório, em **Settings**, procure *Machine inactivity limit* e veja a coluna **Winning GPO**.
1. Volte a mover a CL01 para `Postos` (fora da OU TI).

---

## Exercício 4: Windows LAPS

### Tarefa 8: Preparar o AD

1. No **ADM01**, PowerShell como `CONTOSO\Administrator`:

   ```powershell
   Update-LapsADSchema -Verbose
   Set-LapsADComputerSelfPermission -Identity 'OU=Computadores,OU=_CONTOSO,DC=corp,DC=contoso,DC=com'
   ```

   O primeiro comando acrescenta ao schema os atributos onde as palavras-passe ficam guardadas. O segundo dá a cada computador permissão para escrever **a sua própria** palavra-passe.

> **`Actualização 2026/2027`:** materiais antigos usam o **Microsoft LAPS "legacy"** (MSI separado). O **Windows LAPS** está integrado no Windows Server 2019+ e Windows 10/11 actualizados e é o caminho recomendado. Também pode guardar as palavras-passe no **Microsoft Entra ID** em dispositivos geridos pela cloud.

### Tarefa 9: GPO do LAPS

1. Em GPMC, botão direito em **_CONTOSO > Computadores** > **Create a GPO...** > `GPO-CONTOSO-LAPS`.
1. **Edit** > **Computer Configuration > Policies > Administrative Templates > System > LAPS**:
   - *Configure password backup directory* = **Enabled**, *Backup directory* = **Active Directory**.
   - *Password Settings* = **Enabled**: complexidade *Large letters + small letters + numbers + specials*, comprimento `16`, idade `30` dias.
1. Na **CL01**: `gpupdate /force`.

### Tarefa 10: Ler a palavra-passe

1. No **ADM01**:

   ```powershell
   Get-LapsADPassword -Identity CMB31-CL01 -AsPlainText
   ```

1. Force uma rotação na CL01 (PowerShell como administrador local ou de domínio) e leia de novo:

   ```powershell
   Reset-LapsPassword
   ```

1. Volte a correr `Test-ContosoGpo.ps1` na CL01: todas as linhas devem estar `OK`.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB04`:

1. Saída do `Test-ContosoGpo.ps1` na CL01 com tudo `OK` (sessão da Patrícia, Marketing).
1. Relatório **Group Policy Results** em HTML (botão direito no relatório > **Save Report**).
1. Saída do `Get-LapsADPassword` (pode ocultar a palavra-passe na captura).

## Validação

- [ ] Palavras-passe com mínimo 12 caracteres; conta bloqueia após 10 tentativas.
- [ ] Postos bloqueiam aos 10 minutos e mostram aviso legal.
- [ ] Painel de Controlo bloqueado **só** para o Marketing.
- [ ] Sabe explicar LSDOU, Block Inheritance e Enforced com o exemplo do lab.
- [ ] Windows LAPS a gerir a palavra-passe do administrador local da CL01.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `gpresult` não mostra a GPO | O objecto não está na OU onde a GPO está ligada | Computador: GPO na OU do **computador**. Utilizador: GPO na OU do **utilizador**. |
| GPO de utilizador não se aplica na CL01 | Sessão iniciada com conta local | Entre com `CONTOSO\...`. |
| `gpupdate`: *"The processing of Group Policy failed... could not resolve the domain name"* | DNS errado na CL01 | DNS só `10.31.10.10`. |
| `Get-LapsADPassword` sem resultado | GPO ainda não aplicada ou computador fora da OU | `gpupdate /force` na CL01; ver **Event Viewer > Applications and Services Logs > Microsoft > Windows > LAPS**. |
| Política de palavra-passe numa OU "não funciona" | Só tem efeito ao nível do domínio | Use a Default Domain Policy ou Fine-Grained Password Policies. |

## Challenge

1. **Desenho melhor para o TI:** em vez de Enforced, como garantiria a firewall em todos os postos **e** os 30 minutos para o TI? (Dica: separe as definições em GPOs diferentes e use Enforced só na GPO da firewall.) Implemente.
1. **Fine-Grained Password Policy:** crie uma PSO que obrigue as contas da OU `Admins` (via um grupo `GG_Admins`) a ter **20 caracteres**, sem mexer nos restantes utilizadores. Ferramenta: **Active Directory Administrative Center > System > Password Settings Container**.

## Cleanup

Remova a OU `Postos\TI` de teste (desproteja-a primeiro) se não a usar no Challenge. Mantenha as restantes GPOs.

## Resultado esperado

As regras da CONTOSO vivem num único sítio e chegam sozinhas a cada PC. O administrador consegue explicar **porque** uma definição se aplica e cada PC tem uma palavra-passe de administrador local única e rotativa.

**Próximo lab:** [LAB05 - File Server e permissões](LAB_05_File_Server_e_Permissoes.md)
