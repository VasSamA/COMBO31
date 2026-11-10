---
lab:
    title: 'LAB09 - MFA, SSPR e Conditional Access'
    module: 'Domingo 3 - Microsoft 365 Identity & Access'
---

# LAB09 - MFA, SSPR e Conditional Access

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB09 | Microsoft Entra ID P1: métodos de autenticação, SSPR, Conditional Access | 105 min | 3 |

## O problema

Desde o LAB08, as identidades da CONTOSO estão na Internet. Na semana passada, a Directora Financeira, Helena Matos, recebeu um e-mail "do banco" e introduziu a palavra-passe numa página falsa. Com apenas essa palavra-passe, um atacante pode agora entrar no e-mail dela **a partir de qualquer país**.

Ao mesmo tempo, o Suporte gasta horas por semana a repor palavras-passe esquecidas.

A direcção quer: *"Quem entra de fora do escritório prova quem é. Os administradores provam sempre. As pessoas resolvem sozinhas as palavras-passe esquecidas."*

## O que este lab resolve

A CONTOSO substitui os Security defaults por **políticas de Conditional Access desenhadas para o seu negócio**: MFA obrigatório para administradores, MFA para utilizadores fora do escritório, bloqueio de protocolos antigos que não suportam MFA. Os colaboradores passam a **repor a própria palavra-passe** (SSPR), e a nova palavra-passe é **escrita no AD local** (writeback). Tudo testado com a ferramenta **What If** e com os **sign-in logs**.

## Objectivos

- Configurar a política de métodos de autenticação (Authenticator, passkeys).
- Registar MFA como utilizador.
- Activar SSPR com writeback para o AD.
- Criar uma localização com nome (named location).
- Desactivar Security defaults e criar 3 políticas de Conditional Access, começando em **Report-only**.
- Testar com What If e analisar sign-in logs.

## Pré-requisitos

- [LAB08](LAB_08_Identidade_Hibrida.md) concluído (Password writeback activo).
- VMs a ligar: **CMB31-DC01, CMB31-ADM01, CMB31-CL01**.
- Telemóvel com **Microsoft Authenticator**.
- **Credenciais da break-glass (LAB07) à mão.**

## Topologia: políticas a criar

| Política | Utilizadores | Condição | Controlo | Estado final |
|---|---|---|---|---|
| `CA001-Admins-Exigir-MFA` | Papéis de administrador | Todas as apps | Exigir MFA | On |
| `CA002-Todos-Bloquear-Auth-Legada` | Todos | Client apps: *Exchange ActiveSync* + *Other clients* | Bloquear | On |
| `CA003-Piloto-MFA-Fora-do-Escritorio` | GG_TI, GG_Financeiro, GG_RH | Qualquer local **excepto** `CONTOSO-Escritorio` | Exigir MFA | Report-only > On |

**Exclusão em todas:** `bg-admin01` (break-glass).

## Credenciais

`admin@<tenant>` | `bg-admin01@<tenant>` | `helena.matos@<tenant>`, `paulo.kiala@<tenant>` / `Contoso#2027`.

---

## Exercício 1: Métodos de autenticação e registo

### Tarefa 1: Rever a política de métodos

1. `https://entra.microsoft.com` > **Protection > Authentication methods > Policies**.
1. **Microsoft Authenticator:** Enabled, target **All users**. Abra **Configure** e confirme **Show application name** e **Show geographic location** em **Enabled** (ajuda o utilizador a detectar pedidos falsos).
1. **Passkey (FIDO2):** Enabled, target **All users**, e em **Configure** permita **passkeys no Microsoft Authenticator**.
1. **SMS** e **Voice call:** deixe **desactivados**. São os métodos mais fracos (SIM swapping).

> **`Actualização 2026/2027`:** a gestão de métodos passou toda para a **Authentication methods policy**. As antigas páginas "MFA por utilizador" (*legacy per-user MFA*) e as definições de métodos dentro do SSPR estão a ser descontinuadas. Use **Conditional Access** para exigir MFA, nunca o MFA por utilizador.

### Tarefa 2: Registar MFA como utilizador

1. Numa janela privada, entre em `https://aka.ms/mysecurityinfo` como `helena.matos@<tenant>.onmicrosoft.com`.
1. **+ Add sign-in method > Microsoft Authenticator** e siga o assistente (código QR).
1. Adicione também um **e-mail alternativo** (pode ser o seu e-mail pessoal) como segundo método para SSPR.
1. Repita para `paulo.kiala`.

---

## Exercício 2: SSPR com writeback

### Tarefa 3: Activar o SSPR

1. **Protection > Password reset > Properties:** **Self service password reset enabled = Selected** > grupo `GG_Financeiro` (piloto). **Save**.
1. **Authentication methods:** *Number of methods required to reset* = **2**.
1. **Registration:** *Require users to register when signing in* = **Yes**.
1. **On-premises integration:** confirme **Write back passwords to your on-premises directory = Yes** (vem do LAB08). Marque **Allow users to unlock accounts without resetting their password = Yes**.

### Tarefa 4: Testar o ciclo completo (cloud > AD)

1. Numa janela privada, abra `https://aka.ms/sspr` e reponha a palavra-passe de `helena.matos@<tenant>.onmicrosoft.com`. Nova palavra-passe: `Contoso#2027!SSPR`.
1. Na **CL01**, termine qualquer sessão e entre como `CONTOSO\helena.matos` **com a nova palavra-passe**. Funciona: a palavra-passe definida na cloud foi escrita no AD local.
1. No ADM01, confirme a data da alteração:

   ```powershell
   Get-ADUser helena.matos -Properties PasswordLastSet | Select-Object Name, PasswordLastSet
   ```

---

## Exercício 3: Conditional Access

### Tarefa 5: Localização com nome

1. Descubra o **IP público** da sua ligação: pesquise "what is my ip" no browser do portátil.
1. **Protection > Conditional Access > Named locations > + IP ranges location**:
   - Nome: `CONTOSO-Escritorio`
   - **Mark as trusted location**: marcado
   - Intervalo: `<seu IP público>/32`

> Em casa, o seu IP público pode mudar quando o router reinicia. Se o CA003 começar a pedir MFA "sem razão", actualize este intervalo.

### Tarefa 6: Desactivar os Security defaults

Conditional Access e Security defaults **não podem coexistir**.

1. **Identity > Overview > Properties > Manage security defaults** > **Disabled**. Motivo: *My organization is using Conditional Access*. **Save**.

> A partir deste momento, **não existe MFA obrigatório** até criar as políticas abaixo. Faça as Tarefas 7 a 9 **de seguida**.

### Tarefa 7: CA001 - Administradores exigem sempre MFA

1. **Protection > Conditional Access > Policies > + New policy**. Nome `CA001-Admins-Exigir-MFA`.
1. **Users > Include > Select users and groups > Directory roles:** Global Administrator, Privileged Role Administrator, User Administrator, Helpdesk Administrator, Security Administrator, Conditional Access Administrator, Exchange Administrator, SharePoint Administrator, Intune Administrator.
1. **Users > Exclude:** `bg-admin01`.
1. **Target resources > Resources (formerly cloud apps) > Include > All resources**.
1. **Grant > Grant access > Require multifactor authentication**.
1. **Enable policy = On** > **Create**.

### Tarefa 8: CA002 - Bloquear autenticação legada

1. Nova política `CA002-Todos-Bloquear-Auth-Legada`.
1. **Users:** Include **All users**; Exclude `bg-admin01`.
1. **Target resources:** All resources.
1. **Conditions > Client apps > Configure = Yes:** marque **apenas** **Exchange ActiveSync clients** e **Other clients**.
1. **Grant > Block access**. **Enable policy = On**.

> Protocolos legados (POP, IMAP, SMTP AUTH básico, clientes antigos) **não conseguem fazer MFA**. Um atacante com a palavra-passe da Helena usaria precisamente esta porta.

### Tarefa 9: CA003 - MFA fora do escritório (piloto)

1. Nova política `CA003-Piloto-MFA-Fora-do-Escritorio`.
1. **Users:** Include `GG_TI`, `GG_Financeiro`, `GG_RH`; Exclude `bg-admin01`.
1. **Target resources:** All resources.
1. **Network:** **Configure = Yes**, Include **Any network or location**, Exclude **Selected networks and locations > CONTOSO-Escritorio**.
1. **Grant > Require multifactor authentication**.
1. **Enable policy = Report-only** > **Create**.

### Tarefa 10: Testar antes de activar (What If)

1. **Policies > What If**:
   - User: `helena.matos`; Target: **Office 365**; IP address: um IP qualquer **diferente** do seu (ex.: `41.63.1.1`); Country: Angola.
   - **What If**: deve aparecer `CA003` em **Policies that will apply** (Report-only) e `CA002` não (cliente moderno).
1. Repita com o **seu** IP público: `CA003` aparece em **Policies that will not apply** (localização excluída).
1. Entre como `helena.matos` em `https://outlook.office.com` numa janela privada.
1. **Monitoring & health > Sign-in logs** > abra o sign-in da Helena > separador **Report-only**: veja o resultado que a CA003 **teria** tido.
1. Satisfeito(a) com o resultado, edite `CA003` e mude para **On**.

### Tarefa 11: Provar que funciona

1. Para simular "fora do escritório", **remova temporariamente** o seu IP da named location `CONTOSO-Escritorio` (deixe um IP qualquer, ex.: `10.255.255.255/32`).
1. Entre como `helena.matos` numa janela privada: **é pedido MFA**.
1. Entre como `teste.cloud` (não está no piloto): não é pedido MFA pela CA003.
1. Reponha o seu IP na named location.
1. **Sign-in logs:** abra o sign-in da Helena > separador **Conditional Access** > `CA003` = **Success** com **Grant controls: Require MFA**.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB09`:

1. Captura da lista de políticas de CA (3 políticas, estados correctos).
1. Captura do resultado **What If** para a Helena com IP externo.
1. Captura do separador **Conditional Access** de um sign-in da Helena.
1. Saída do `PasswordLastSet` da Helena após o SSPR.

## Validação

- [ ] Security defaults desactivados **e** 3 políticas CA activas.
- [ ] Break-glass excluída de todas as políticas.
- [ ] Administradores exigem MFA sempre; utilizadores piloto exigem MFA fora do escritório.
- [ ] Autenticação legada bloqueada.
- [ ] SSPR funciona e a nova palavra-passe chega ao AD.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| Fiquei bloqueado(a) fora do portal | Política mal configurada | Entre com `bg-admin01` e corrija/desactive a política. |
| SSPR: *"Your organization's on-premises directory couldn't update your password"* | Writeback não activo ou ADM01 desligado | Ligue o ADM01; confirme writeback no Entra Connect e em **Password reset > On-premises integration**. |
| SSPR: palavra-passe rejeitada | Não cumpre a política do AD (LAB04: 12 caracteres) | Use uma palavra-passe mais longa. |
| CA003 aplica-se mesmo no escritório | IP público mudou | Actualize a named location. |
| What If não mostra a política | Utilizador não está no grupo, ou política desactivada | Verifique **Users** e o estado da política. |

## Challenge

1. **Passwordless:** registe uma **passkey no Microsoft Authenticator** para o `paulo.kiala` e entre em `https://myaccount.microsoft.com` **sem escrever a palavra-passe**.
1. **Authentication strength:** altere a CA001 para exigir **Phishing-resistant MFA** (authentication strength) em vez de "Require multifactor authentication". Explique porque é que um código de 6 dígitos ou uma notificação por push ainda podem ser "phishados" e uma passkey não.

> **Nota sobre Identity Protection:** políticas baseadas em **risco de utilizador e de sign-in** (ex.: "bloquear sign-ins de alto risco") exigem **Microsoft Entra ID P2**, que **não** está incluído no Business Premium. O instrutor pode demonstrá-las num tenant com P2 (ex.: Microsoft 365 E5). Os conceitos são os mesmos das políticas deste lab, com a condição **User risk / Sign-in risk**.

## Cleanup

Nada a apagar. Mantenha as políticas: o LAB10 acrescenta a exigência de **dispositivo em conformidade**.

## Resultado esperado

Uma palavra-passe roubada já não chega para entrar na CONTOSO a partir de fora. Os administradores provam sempre quem são, os protocolos antigos estão fechados e os utilizadores resolvem sozinhos as palavras-passe esquecidas. **Fim do Domingo 3.**

**Próximo lab:** [LAB10 - Microsoft Intune](LAB_10_Microsoft_Intune.md)
