# CAPSTONE - Checklist de evidências

Para cada requisito: uma captura de ecrã **ou** a saída de um comando que **prove** que está cumprido, e uma linha a explicar o que a evidência mostra.

| ID | Cumprido? | Evidência (ficheiro / comando) | O que prova |
|---|---|---|---|
| WS-1 | [ ] | | |
| WS-2 | [ ] | | |
| WS-3 | [ ] | | |
| WS-4 | [ ] | | |
| M365-1 | [ ] | | |
| M365-2 | [ ] | | |
| M365-3 | [ ] | | |
| M365-4 | [ ] | | |
| M365-5 | [ ] | | |
| AZ-1 | [ ] | | |
| AZ-2 | [ ] | | |
| AZ-3 | [ ] | | |
| AZ-4 | [ ] | | |
| AZ-5 | [ ] | | |
| SEC-1 | [ ] | | |
| SEC-2 | [ ] | | |
| SEC-3 | [ ] | | |
| DOC-1 | [ ] | | |

## Comandos úteis para evidências

```powershell
# AD
Get-ADOrganizationalUnit -Filter * -SearchBase 'OU=_CONTOSO,DC=corp,DC=contoso,DC=com' | Select Name, DistinguishedName
Get-ADGroupMember <grupo> | Select Name
icacls \\CMB31-SRV01\E$\Shares\Logistica

# Entra Connect
Get-ADSyncScheduler

# Azure
Get-AzResource -ResourceGroupName <rg> | Select Name, ResourceType, Location, Tags
Get-AzPolicyState -ResourceGroupName <rg> | Where ComplianceState -eq 'NonCompliant'
Get-AzNetworkSecurityGroup -Name <nsg> -ResourceGroupName <rg> | Select -Expand SecurityRules | Select Name, Priority, Access, SourceAddressPrefix, DestinationPortRange
```
