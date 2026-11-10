---
lab:
    title: 'LAB15 - Azure Storage'
    module: 'Domingo 5 - Microsoft Azure Infrastructure'
---

# LAB15 - Azure Storage

| Código | Tecnologia | Duração | Domingo |
|---|---|---|---|
| LAB15 | Storage account, Blob, access tiers, lifecycle management, SAS, RBAC de dados, AzCopy, Azure Files, firewall de storage | 105 min | 5 |

## O problema

O disco do File Server da CONTOSO (`\\CMB31-SRV01`, LAB05) está a encher. Quase metade do espaço são **facturas e campanhas de anos anteriores**, que quase ninguém abre mas que **têm de ser guardadas** durante anos. Comprar mais discos para o escritório não resolve: o edifício continua a ser um ponto único de falha.

Além disso, a aplicação que acabou de ir para o Azure (LAB14) precisa de uma **pasta partilhada** para trocar ficheiros, e o Marketing quer enviar **um link temporário** a uma agência para descarregar imagens, sem lhe criar conta.

## O que este lab resolve

A CONTOSO passa a ter uma **storage account segura e governada**: o **arquivo morto** migrado do File Server local para Blob Storage com **mudança automática para camadas mais baratas**, **acessos temporários** com SAS, permissões de dados por **RBAC**, uma **partilha Azure Files** montada na VM da aplicação e a conta **fechada à Internet** excepto para as redes autorizadas.

## Objectivos

- Criar uma storage account com definições de segurança correctas.
- Carregar dados a partir do on-premises com AzCopy.
- Configurar access tiers e uma regra de lifecycle management.
- Partilhar com SAS e atribuir papéis de dados (Storage Blob Data Reader).
- Criar uma partilha Azure Files e montá-la numa VM.
- Restringir o acesso por rede (firewall + service endpoint).
- Recuperar um blob apagado (soft delete).

## Pré-requisitos

- [LAB13](LAB_13_Azure_Governance.md) concluído. [LAB14](LAB_14_VNet_e_VM.md) para a Parte Azure Files.
- [LAB05](LAB_05_File_Server_e_Permissoes.md) para a migração a partir do on-premises (VMs **CMB31-DC01, CMB31-SRV01, CMB31-ADM01** ligadas). Sem VMs locais, carregue ficheiros quaisquer a partir do portátil.
- Cloud Shell com `$ini`, `$loc`, `$tags`.

## Topologia

```text
 On-premises                                        Azure: rg-contoso-data-<ini>
 \\CMB31-SRV01\Comum ─(AzCopy, HTTPS)──▶ stcontoso<ini><nn>
                                          ├── Blob: arquivo-morto   (Hot -> Cool 30d -> Archive 180d)
                                          ├── Blob: marketing-agencia  (SAS só leitura, 24h)
                                          └── Files: comum-cloud (100 GiB) ◀── SMB 445 ── vm-contoso-app01
                                        Firewall: snet-app (service endpoint) + IP público do escritório
```

## Credenciais

`admin@<tenant>` | `paulo.kiala@<tenant>` (Reader do LAB13) | `azureadmin` (VM).

---

## Exercício 1: Storage account

### Tarefa 1: Criar com definições seguras

1. Portal > **Storage accounts > Create**:
   - RG `rg-contoso-data-<ini>`, nome `stcontoso<ini><nn>` (único no mundo: se estiver ocupado, mude o número).
   - Região do curso. **Primary service:** Azure Blob Storage or Azure Data Lake Storage Gen 2. **Performance:** Standard. **Redundancy:** **LRS**.
1. **Advanced:**
   - **Require secure transfer for REST API operations:** marcado.
   - **Allow enabling anonymous access on individual containers:** **desmarcado**.
   - **Minimum TLS version:** 1.2.
   - **Default to Microsoft Entra authorization in the Azure portal:** marcado.
   - **Access tier:** Hot.
1. **Networking:** por agora, **Enable public access from all networks** (vai fechar no Exercício 4).
1. **Data protection:** **Enable soft delete for blobs** = 7 dias; **Enable soft delete for containers** = 7 dias; **Enable soft delete for file shares** = 7 dias.
1. **Tags:** as da CONTOSO. **Review + create**.

> **Redundância:** LRS guarda 3 cópias **no mesmo datacenter**. Para dados de negócio em produção, a CONTOSO ponderaria **ZRS** (3 zonas) ou **GRS** (cópia noutra região). Em laboratório, LRS é o mais barato.

### Tarefa 2: Criar os contentores

1. **Data storage > Containers > + Container:** `arquivo-morto` e `marketing-agencia`, ambos **Private (no anonymous access)**.

---

## Exercício 2: Migrar o arquivo morto do on-premises

### Tarefa 3: Preparar dados no File Server

1. No **ADM01**, crie dados fictícios de "arquivo" na partilha Comum:

   ```powershell
   $dest = '\\CMB31-SRV01\Comum\Arquivo_2019_2021'
   New-Item -ItemType Directory $dest -Force | Out-Null
   1..30 | ForEach-Object { Set-Content "$dest\Factura_2020_$('{0:d3}' -f $_).txt" "Factura fictícia n.º $_ - CONTOSO Angola" }
   ```

### Tarefa 4: SAS de escrita temporária

1. Portal > storage account > **Containers > arquivo-morto > Shared access tokens**:
   - **Signing method:** Account key.
   - **Permissions:** Read, Add, Create, Write, List.
   - **Expiry:** daqui a **2 horas**. **Allowed protocols:** HTTPS only.
   - **Generate SAS token and URL**. Copie o **Blob SAS URL**.

### Tarefa 5: AzCopy

1. No **ADM01**, descarregue o AzCopy v10 para Windows a partir de `https://aka.ms/downloadazcopy-v10-windows` e extraia para `C:\Tools\azcopy`.
1. Execute (cole o URL entre aspas simples):

   ```powershell
   cd C:\Tools\azcopy\azcopy_windows_amd64_*
   .\azcopy.exe copy '\\CMB31-SRV01\Comum\Arquivo_2019_2021' '<Blob SAS URL>' --recursive
   ```

1. Confirme no portal: `arquivo-morto/Arquivo_2019_2021/` com 30 ficheiros.
1. Depois de validar, a CONTOSO **removeria** a pasta do File Server local para libertar espaço. Faça-o:

   ```powershell
   Remove-Item '\\CMB31-SRV01\Comum\Arquivo_2019_2021' -Recurse -Force
   ```

> Em migrações grandes (terabytes), a mesma lógica aplica-se com AzCopy em lotes, **Azure Storage Mover** ou, sem largura de banda suficiente, **Azure Data Box** (disco físico enviado à Microsoft).

---

## Exercício 3: Custos e acessos

### Tarefa 6: Access tiers e lifecycle

1. Abra um ficheiro em `arquivo-morto` > **Change tier** > **Cool**. Observe as opções **Hot, Cool, Cold, Archive**.

   | Tier | Armazenamento | Leitura | Uso na CONTOSO |
   |---|---|---|---|
   | Hot | Mais caro | Mais barata | Ficheiros em uso |
   | Cool / Cold | Mais barato | Mais cara, mínimo 30/90 dias | Arquivo consultado raramente |
   | Archive | O mais barato | Offline: **reidratação demora horas** | Arquivo legal |

1. **Data management > Lifecycle management > Add a rule**:
   - Nome `arquivo-para-frio`, **Limit blobs with filters**, Blob type **Block blobs**.
   - **Base blobs:** *Last modified* > 30 dias > **Move to cool storage**; > 180 dias > **Move to archive storage**; > 3650 dias > **Delete the blob**.
   - **Filter set:** prefix `arquivo-morto/`.
   - **Add**.

### Tarefa 7: Link temporário para a agência (SAS)

1. Carregue para `marketing-agencia` uma imagem qualquer (`campanha.png`).
1. No ficheiro > **Generate SAS:** permissão **Read**, expiração **24 horas**, HTTPS only > **Generate**.
1. Abra o **Blob SAS URL** numa janela privada: a imagem abre **sem login**.
1. Abra o URL **sem** a parte `?sv=...`: **erro** (ResourceNotFound / PublicAccessNotPermitted). Sem SAS não há acesso anónimo.

> **Risco de SAS:** quem tiver o link tem acesso até expirar. Em produção prefere-se **User delegation SAS** (assinada com credenciais Entra, revogável) e prazos curtos.

### Tarefa 8: RBAC no plano de dados

1. Numa janela privada, entre como `paulo.kiala` (Reader na subscription, LAB13) > storage account > **Containers > arquivo-morto**. Vê o contentor mas **não consegue listar os ficheiros** (*You do not have permissions to list the data*).

   > **Reader** é um papel de **plano de gestão** (ver o recurso). Ler os **dados** exige um papel de **plano de dados**.

1. Como `admin`, na storage account > **Access control (IAM) > Add role assignment** > **Storage Blob Data Reader** > `paulo.kiala`.
1. Após alguns minutos, o Paulo já lista e descarrega os ficheiros.

---

## Exercício 4: Azure Files e segurança de rede

### Tarefa 9: Partilha Azure Files

1. Storage account > **Data storage > File shares > + File share:** nome `comum-cloud`, tier **Transaction optimized**, quota **100 GiB** (se pedido).
1. Abra a partilha > **Connect** > **Windows**, letra **Z**, **Storage account key** > copie o script.

### Tarefa 10: Montar na VM da aplicação

1. Inicie a `vm-contoso-app01` e ligue-se via **Bastion**.
1. Cole o script num PowerShell. A unidade **Z:** aparece.
1. Crie `Z:\encomendas_hoje.csv` e confirme no portal que o ficheiro existe.

### Tarefa 11: Fechar a storage account à Internet

1. Storage account > **Security + networking > Networking > Firewalls and virtual networks**:
   - **Public network access:** **Enabled from selected virtual networks and IP addresses**.
   - **Virtual networks > + Add existing virtual network:** `vnet-contoso-app-<ini>` / `snet-app` (o portal activa o **service endpoint Microsoft.Storage** na subnet).
   - **Firewall > Add your client IP address** (o IP público de onde está a trabalhar, para continuar a usar o portal).
   - **Save**.
1. Teste:
   - Na VM: `dir Z:\` continua a funcionar (via service endpoint).
   - No Cloud Shell (que **não** está na sua lista): `Get-AzStorageBlob -Container arquivo-morto -Context (New-AzStorageContext -StorageAccountName stcontoso<ini><nn> -UseConnectedAccount)` **falha** com *AuthorizationFailure / This request is not authorized*.

### Tarefa 12: Recuperar um blob apagado

1. Apague `arquivo-morto/Arquivo_2019_2021/Factura_2020_001.txt` no portal.
1. No contentor, active **Show deleted blobs**. O ficheiro aparece como **Deleted**.
1. Seleccione-o > **Undelete**.

---

## Evidência de conclusão

Guarde em `Evidencias\LAB15`:

1. Saída final do AzCopy (`Final Job Status: Completed`).
1. Captura da regra de lifecycle.
1. Captura do acesso negado do Paulo **antes** e da listagem **depois** do papel de dados.
1. `dir Z:\` na VM.
1. Erro de autorização a partir do Cloud Shell após fechar a firewall.
1. Captura do blob recuperado.

## Validação

- [ ] Storage account com HTTPS obrigatório, TLS 1.2, sem acesso anónimo e soft delete.
- [ ] Arquivo migrado do File Server local para Blob e removido do local.
- [ ] Lifecycle: Cool 30 dias, Archive 180 dias.
- [ ] SAS temporária funciona; sem SAS não há acesso.
- [ ] Paulo lê dados só depois de Storage Blob Data Reader.
- [ ] Azure Files montado na VM; storage fechada às redes autorizadas.

## Troubleshooting

| Sintoma | Solução |
|---|---|
| AzCopy: `403 AuthorizationPermissionMismatch` | SAS sem permissões Write/Create ou expirada. Gere de novo. |
| AzCopy: `This request is not authorized` | A firewall da storage já está fechada. Adicione o IP público do seu portátil (Exercício 4) ou faça o Exercício 2 antes. |
| Montagem da unidade Z: falha com erro 53/67 | Porta 445 bloqueada. Dentro do Azure funciona; a partir de casa, muitos ISP bloqueiam 445 (por isso montamos na VM). |
| O portal deixou de mostrar os ficheiros após fechar a firewall | O seu IP público mudou. Actualize-o em **Firewall**. |
| Paulo continua sem ver os dados | Atribuições de dados demoram até 10 min. Faça logout/login. |

## Challenge

1. Substitua o acesso com **storage account key** no Azure Files por **identidade**: explique (em 5 linhas) o que a CONTOSO precisaria para que os utilizadores do AD montassem `comum-cloud` com as **suas credenciais do domínio** e permissões NTFS (dica: *Azure Files identity-based authentication* com AD DS e identidades híbridas do LAB08).
1. Configure **Private Endpoint** para o serviço **file** da storage account em `snet-app` e prove com `Resolve-DnsName stcontoso<ini><nn>.file.core.windows.net` na VM que o nome resolve para um **IP privado** 10.60.1.x.

## Cleanup

1. Desmonte a unidade Z: na VM (`net use Z: /delete`) e **pare a VM**.
1. Mantenha a storage account (custo residual). Será eliminada com o RG no fim do curso.

## Resultado esperado

O File Server da CONTOSO libertou espaço, o arquivo legal está fora do edifício e fica mais barato com o tempo, as partilhas com externos expiram sozinhas, e os dados só são acessíveis a partir de redes e pessoas autorizadas. **Fim do Domingo 5.**

**Próximo lab:** [LAB16 - Azure Monitor + Azure Arc](LAB_16_Azure_Monitor_e_Arc.md)
