@description('Location for all resources.')
param location string = resourceGroup().location

@description('Resource Name for Public IP address attached to Hyper-V Host')
param HostPublicIPAddressName string = 'HVHOSTPIP'

@description('Hyper-V Host and Guest VMs Virtual Network')
param virtualNetworkName string = 'VirtualNetwork'

@description('Virtual Network Address Space')
param virtualNetworkAddressPrefix string = '10.0.0.0/22'

@description('Hyper-V Host Subnet Name')
param hyperVSubnetName string = 'Hyper-V-LAN'

@description('Hyper-V Host Subnet Address Space')
param hyperVSubnetPrefix string = '10.0.1.0/24'

@description('Azure VMs Subnet Name')
param azureVMsSubnetName string = 'Azure-VMs'

@description('Hyper-V Host Network Interface 1 Name, attached to NAT Subnet')
param HostNetworkInterface1Name string = 'HVHOSTNIC1'

@description('Hyper-V Host Network Interface 2 Name, attached to Hyper-V LAN Subnet')
param HostNetworkInterface2Name string = 'HVHOSTNIC2'

@description('Name of Hyper-V Host Virtual Machine, Maximum of 15 characters, use letters and numbers only.')
@maxLength(15)
param HostVirtualMachineName string = 'HVHOST'

@description('Size of the Host Virtual Machine')
@allowed([
  'Standard_D2_v3'
  'Standard_D4_v3'
  'Standard_D8_v3'
  'Standard_D16_v3'
  'Standard_D32_v3'
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
  'Standard_D16s_v3'
  'Standard_D32s_v3'
  'Standard_D64_v3'
  'Standard_E2_v3'
  'Standard_E4_v3'
  'Standard_E8_v3'
  'Standard_E16_v3'
  'Standard_E32_v3'
  'Standard_E64_v3'
  'Standard_D64s_v3'
  'Standard_E2s_v3'
  'Standard_E4s_v3'
  'Standard_E8s_v3'
  'Standard_E16s_v3'
  'Standard_E32s_v3'
  'Standard_E64s_v3'
])
param HostVirtualMachineSize string = 'Standard_D4s_v3'

@description('Admin Username for the Host Virtual Machine')
param HostAdminUsername string

@description('Admin User Password for the Host Virtual Machine')
@secure()
param HostAdminPassword string

var hyperVSubnetNSGName = '${hyperVSubnetName}NSG'
var azureVMsSubnetNSGName = '${azureVMsSubnetName}NSG'
var DSCInstallWindowsFeaturesUri = uri(dsc/hypervinstall.zip)

resource publicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: HostPublicIPAddressName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: toLower('${HostVirtualMachineName}-${uniqueString(resourceGroup().id)}')
    }
  }
}

resource hyperVNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: hyperVSubnetNSGName
  location: location
  properties: {}
}

resource azureVmsSubnet 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: azureVMsSubnetNSGName
  location: location
  properties: {}
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: hyperVSubnetName
        properties: {
          addressPrefix: hyperVSubnetPrefix
          networkSecurityGroup: {
            id: hyperVNsg.id
          }
        }
      }
    ]
  }
}

module createNic1 './nic.bicep' = {
  name: 'createNic1'
  params: {
    location: location
    nicName: HostNetworkInterface2Name
    enableIPForwarding: true
    subnetId: '${vnet.id}/subnets/${hyperVSubnetName}'
  }
}

// update nic to staticIp now that nic has been created
module updateNic1 './nic.bicep' = {
  name: 'updateNic1'
  params: {
    location: location
    ipAllocationMethod: 'Static'
    staticIpAddress: createNic1.outputs.assignedIp
    nicName: HostNetworkInterface1Name
    subnetId: '${vnet.id}/subnets/${hyperVSubnetName}'
    pipId: publicIp.id
  }
}

resource hostVm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: HostVirtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: HostVirtualMachineSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${HostVirtualMachineName}OsDisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        caching: 'ReadWrite'
      }
      dataDisks: [
        {
          lun: 0
          name: '${HostVirtualMachineName}DataDisk1'
          createOption: 'Empty'
          diskSizeGB: 1024
          caching: 'ReadOnly'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    osProfile: {
      computerName: HostVirtualMachineName
      adminUsername: HostAdminUsername
      adminPassword: HostAdminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: createNic1.outputs.nicId
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: hostVm
  name: 'InstallWindowsFeatures'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: DSCInstallWindowsFeaturesUri
        script: 'hypervinstall.ps1'
        function: 'InstallWindowsFeatures'
      }
    }
  }
}

