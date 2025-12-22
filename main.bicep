@description('Location for all resources')
param location string = 'japaneast'

@description('Admin username for the Virtual Machine')
param adminUsername string

@description('Admin password for the Virtual Machine')
@secure()
param adminPassword string

@description('Virtual Network name')
param vnetName string = 'vnet-bicep'

@description('Network Security Group name')
param nsgName string = 'nsg-bicep'

@description('Public IP name')
param pipName string = 'pip-vm-bicep'

@description('Network Interface name')
param nicName string = 'nic-vm-bicep'

@description('Virtual Machine name')
param vmName string = 'vm-bicep'

@description('Data disk name')
param dataDiskName string = 'disk-bicep'

@description('DSC package URL (leave empty to skip DSC configuration)')
param dscPackageUrl string = ''

@description('Blob Storage URL for web content (leave empty to skip)')
param blobStorageUrl string = ''

module network 'modules/network.bicep' = {
  params: {
    location: location
    vnetName: vnetName
    nsgName: nsgName
    pipName: pipName
    nicName: nicName
  }
}

module virtualMachine 'modules/virtualMachine.bicep' = {
  name: 'vm-deployment'
  params: {
    location: location
    vmName: vmName
    adminUsername: adminUsername
    adminPassword: adminPassword
    nicId: network.outputs.nicId
    dataDiskName: dataDiskName
    dscPackageUrl: dscPackageUrl
    blobStorageUrl: blobStorageUrl
  }
}

@description('Public IP Address of the VM')
output publicIPAddress string = network.outputs.publicIPAddress

@description('Virtual Machine name')
output vmName string = virtualMachine.outputs.vmName
