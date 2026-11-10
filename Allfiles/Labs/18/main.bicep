// COMBO PRO 3 em 1 - LAB18 - Infraestrutura como código
// Cria a rede de recuperação (DR) da CONTOSO: VNet + subnet + NSG, com as tags obrigatórias.
// Deploy:  az deployment group create -g rg-contoso-dr-<iniciais> -f main.bicep -p iniciais=<iniciais>

@description('Iniciais do aluno, usadas nos nomes (ex.: osm)')
@minLength(2)
@maxLength(5)
param iniciais string

@description('Região. Por omissão, a do Resource Group.')
param location string = resourceGroup().location

@description('Espaço de endereçamento da VNet de DR')
param addressPrefix string = '10.70.0.0/16'

var tags = {
  Projecto: 'COMBO'
  Ambiente: 'Lab'
  Dono: iniciais
  CentroCusto: 'TI'
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-snet-dr-${iniciais}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-From-App-VNet'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.60.0.0/16'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-contoso-dr-${iniciais}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ addressPrefix ]
    }
    subnets: [
      {
        name: 'snet-dr'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 1)
          networkSecurityGroup: { id: nsg.id }
          defaultOutboundAccess: false
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output subnetPrefix string = vnet.properties.subnets[0].properties.addressPrefix
