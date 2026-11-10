---
lab:
    title: 'LAB07 - Tenant Microsoft 365, administradores e licenças'
    module: 'Domingo 3 - Microsoft 365 Identity & Access'
---

# LAB07 - Tenant Microsoft 365, administradores e licenças

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB07 | Microsoft 365 admin center, Microsoft Entra ID | 75 min | 3 |

## O problema

A CONTOSO tem agora um domínio interno organizado, mas **nada existe fora do escritório**. Os vendedores usam e-mail pessoal (Gmail, Hotmail) para falar com clientes, os documentos não estão acessíveis fora da rede, e não há forma de colaborar com parceiros. A direcção aprovou a adopção do **Microsoft 365 Business Premium**.

O Director de TI tem uma preocupação: *"Se a única conta de administrador da cloud ficar bloqueada, perdemos o controlo da empresa inteira."*

## O que este lab resolve

A CONTOSO fica com um **tenant Microsoft 365 Business Premium** configurado (perfil da organização, licenças, localização), uma **conta de emergência (break-glass)**, **administradores com o privilégio mínimo** necessário e o primeiro utilizador cloud licenciado. É a "casa" na cloud para onde, no LAB08, vão os 50 utilizadores do AD.

## Objectivos

- Criar (ou activar) o tenant Microsoft 365 Business Premium.
- Configurar o perfil da organização.
- Criar uma conta break-glass e administradores com papéis de privilégio mínimo.
- Compreender licenças e *usage location*.
- (Opcional) Adicionar e verificar um domínio personalizado.
- Verificar o estado dos **Security defaults**.

## Pré-requisitos

- Browser actualizado (Edge ou Chrome), de preferência num perfil/janela privada só para o curso.
- Um endereço de e-mail e um número de telemóvel para o registo do trial.
- **Não depende das VMs.** Pode fazer este lab em qualquer computador.

## Topologia

```text
Tenant: contoso<iniciais><nn>.onmicrosoft.com     (ex.: contosoosm01)
├── admin@...            Global Administrator (conta de criação)
├── bg-admin01@...       Global Administrator (break-glass, cloud-only)
├── adm.nadia@...        User Administrator + Helpdesk Administrator
└── teste.cloud@...      Utilizador cloud licenciado (teste)
Licenças: Microsoft 365 Business Premium (trial, 25 licenças)
```

## Credenciais

Definidas por si. Use palavras-passe **longas e únicas** e guarde-as num gestor de palavras-passe, **nunca** neste repositório.

| Conta | Palavra-passe sugerida |
|---|---|
| `admin@<tenant>` | Escolhida no registo |
| `bg-admin01@<tenant>` | Frase-passe de 25+ caracteres, gerada |
| `adm.nadia@<tenant>`, `teste.cloud@<tenant>` | Escolhida por si |

---

## Exercício 1: Criar o tenant

### Tarefa 1: Registar o trial

1. Numa janela privada, pesquise **"Microsoft 365 Business Premium free trial"** na página oficial da Microsoft e seleccione **Try free for one month**.
1. Preencha com o seu e-mail e siga o assistente:
   - **Company name:** `CONTOSO Angola <suas iniciais>`
   - **Country/region:** **Angola** (importante: define a localização do tenant e o *usage location* por omissão)
   - **Domain name:** `contoso<iniciais><nn>` (ex.: `contosoosm01`). Fica `contosoosm01.onmicrosoft.com`.
   - **Username:** `admin`
1. Conclua o registo. O assistente pode pedir um método de pagamento: se não quiser introduzir cartão, **pare aqui e peça um tenant de reserva à academia**.

> **Se introduzir cartão:** em **Billing > Your products**, desactive a **renovação automática** logo após o registo.

### Tarefa 2: Primeira entrada e perfil da organização

1. Entre em `https://admin.microsoft.com` com `admin@<tenant>.onmicrosoft.com`. Registe o **Microsoft Authenticator** quando pedido (o tenant novo tem Security defaults activos).
1. **Settings > Org settings > Organization profile**:
   - **Organization information:** nome `CONTOSO Angola`, endereço fictício em Luanda.
   - **Release preferences:** **Targeted release for select users** (só o admin), para ver novidades primeiro.
   - **Custom themes:** carregue um logótipo genérico (opcional).
1. **Billing > Licenses:** confirme **Microsoft 365 Business Premium - 25 licenças**.

---

## Exercício 2: Administração segura

### Tarefa 3: Conta break-glass

Uma conta break-glass é uma **conta de emergência cloud-only**, com Global Administrator, que **não depende de nada** do AD local, nem de federação, nem de um telemóvel de um colaborador específico. Usa-se quando as outras contas estão bloqueadas (ex.: uma política de Conditional Access mal configurada no LAB09).

1. Abra `https://entra.microsoft.com` > **Identity > Users > All users > New user > Create new user**:
   - UPN: `bg-admin01@<tenant>.onmicrosoft.com`
   - Display name: `Break Glass 01`
   - Password: gere uma frase-passe longa e **guarde-a fora do computador** (ex.: envelope selado no cofre, em produção).
   - **Assignments > Add role > Global Administrator**.
1. Registe para esta conta um método MFA **que não dependa de uma pessoa** (em produção: chave FIDO2 guardada no cofre). No laboratório, registe o Authenticator no seu telemóvel.

> **`Actualização 2026/2027`:** a Microsoft passou a exigir **MFA obrigatório** para entrar nos portais de administração (Azure, Entra, Intune, Microsoft 365 admin center), **incluindo** contas break-glass. Por isso a recomendação actual é proteger estas contas com **passkey/FIDO2** em vez de as deixar sem MFA. Materiais antigos que dizem "excluir a break-glass de todo o MFA" estão desactualizados.

### Tarefa 4: Administradores com privilégio mínimo

A Nádia (administradora de sistemas) precisa de criar utilizadores e repor palavras-passe. **Não** precisa de ser Global Administrator.

1. Crie o utilizador `adm.nadia@<tenant>.onmicrosoft.com` (Display name `ADM Nádia Sebastião`).
1. **Assigned roles > Add assignments**: `User Administrator` e `Helpdesk Administrator`.
1. Numa outra janela privada, entre como `adm.nadia` em `https://entra.microsoft.com`:
   - Consegue criar um utilizador? **Sim.**
   - Vá a **Protection > Conditional Access**. Consegue criar uma política? **Não**: falta o papel `Conditional Access Administrator` ou `Security Administrator`.
1. Feche a sessão da Nádia.

> **Princípio:** dê o papel mais pequeno que resolve a tarefa. No máximo **2 a 4 Global Administrators** por tenant, incluindo as break-glass.

### Tarefa 5: Primeiro utilizador cloud licenciado

1. Em `https://admin.microsoft.com` > **Users > Active users > Add a user**:
   - Nome `Teste Cloud`, username `teste.cloud`.
   - **Product licenses:** location **Angola**, licença **Microsoft 365 Business Premium**.
1. Em **Users > Active users**, abra `Teste Cloud` > **Licenses and apps** e veja os **serviços incluídos** (Exchange Online, SharePoint, Teams, Intune, Entra ID P1, Defender for Business, Purview Information Protection, etc.).
1. Numa janela privada, entre em `https://outlook.office.com` como `teste.cloud` e envie um e-mail para `admin@<tenant>`.

> **Usage location:** uma licença só pode ser atribuída se o utilizador tiver uma localização de utilização definida (por razões legais de disponibilidade de serviços). Na atribuição por grupo (LAB08), usa-se a localização do tenant quando o utilizador não tem nenhuma.

---

## Exercício 3: Domínio e segurança de base

### Tarefa 6: Domínio personalizado (opcional)

Faça esta tarefa **só se tiver um domínio público seu** (ex.: um domínio de teste comprado barato). Caso contrário, leia os passos e avance.

1. **Settings > Domains > Add domain** > escreva o domínio.
1. Escolha **Add a TXT record to the domain's DNS records**. Copie o valor `MS=ms...`.
1. No painel DNS do seu registo de domínio, crie o registo TXT. Volte e seleccione **Verify**.
1. Na escolha de serviços, **não** configure registos MX nesta fase se o domínio estiver a receber e-mail real.

> **Ligação com o LAB08:** os utilizadores do AD têm UPN `@corp.contoso.com`, que não é verificável. Se verificar um domínio seu, poderá adicioná-lo como sufixo UPN no AD e os utilizadores sincronizados ficarão `nome@seudominio`. Sem domínio verificado, ficam `nome@<tenant>.onmicrosoft.com`, o que é suficiente para o curso.

### Tarefa 7: Security defaults

1. Em `https://entra.microsoft.com` > **Identity > Overview > Properties > Manage security defaults**.
1. Confirme que estão **Enabled**. Leia o que fazem: MFA para todos, bloqueio de autenticação legada, protecção de acções privilegiadas.
1. **Não altere nada.** No LAB09 vai substituí-los por políticas de Conditional Access mais finas (possíveis porque o Business Premium inclui Entra ID P1).

---

## Evidência de conclusão

Guarde em `Evidencias\LAB07` (oculte nomes de tenant reais se partilhar):

1. Captura de **Billing > Licenses** com o Business Premium.
1. Captura de **Roles and administrators > Global Administrator > Assignments** (2 contas: admin e bg-admin01).
1. Captura das funções da `adm.nadia`.
1. Captura do e-mail recebido de `teste.cloud`.

## Validação

- [ ] Tenant `contoso<iniciais><nn>.onmicrosoft.com` com país **Angola**.
- [ ] Exactamente 2 Global Administrators (admin + break-glass).
- [ ] `adm.nadia` só com User Administrator e Helpdesk Administrator.
- [ ] `teste.cloud` licenciado e com caixa de correio funcional.
- [ ] Security defaults activos (até ao LAB09).

## Troubleshooting

| Sintoma | Solução |
|---|---|
| O registo pede cartão e não quer usar | Peça um tenant de reserva à academia. |
| "This domain name is already in use" | Escolha outro sufixo numérico. |
| Licença não se atribui: *"usage location is required"* | Defina **Usage location = Angola** no utilizador. |
| `adm.nadia` não vê o menu de utilizadores | Os papéis demoram alguns minutos a propagar. Feche sessão e entre de novo. |
| Perdi o acesso à conta admin | Entre com a break-glass. É para isto que ela existe. |

## Challenge

Sem o PIM (que exige Entra ID P2), como prova quem deu a alguém o papel de Global Administrator? Adicione o `teste.cloud` ao papel **Global Administrator**, remova-o, e depois encontre os **dois eventos** em **Entra > Monitoring & health > Audit logs** (filtro **Activity** = `Add member to role` / `Remove member from role`). Indique quem fez a alteração e a que horas. Explique em 3 linhas porque é que a CONTOSO deveria, no futuro, enviar estes eventos para um Log Analytics workspace (LAB16) com um alerta.

## Cleanup

Nada a apagar. **Guarde as credenciais da break-glass**: vai precisar delas se ficar bloqueado(a) no LAB09.

## Resultado esperado

A CONTOSO existe na cloud: um tenant com licenças, administradores com privilégio mínimo e uma porta de emergência. Falta trazer as pessoas do AD.

**Próximo lab:** [LAB08 - Identidade híbrida](LAB_08_Identidade_Hibrida.md)
