@description('Location for all resources')
param location string

@description('Virtual Machine name')
param vmName string

@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('Network Interface ID')
param nicId string

@description('Data disk name')
param dataDiskName string

@description('DSC package URL (zip file containing compiled MOF)')
param dscPackageUrl string = ''

@description('Blob Storage URL for web content')
param blobStorageUrl string = ''

resource dataDisk 'Microsoft.Compute/disks@2023-10-02' = {
  name: dataDiskName
  location: location
  sku: {
    name: 'StandardSSD_LRS'
  }
  properties: {
    diskSizeGB: 64
    creationData: {
      createOption: 'Empty'
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          lun: 0
          createOption: 'Attach'
          managedDisk: {
            id: dataDisk.id
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId
        }
      ]
    }
  }
}

// DSC Extension to configure IIS
resource vmDscExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (dscPackageUrl != '') {
  parent: vm
  name: 'Microsoft.Powershell.DSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: dscPackageUrl
        script: 'ConfigureIIS.ps1'
        function: 'ConfigureIIS'
      }
      configurationArguments: {
        MachineName: 'localhost'
        BlobStorageUrl: blobStorageUrl
      }
    }
    protectedSettings: {}
  }
}

@description('Virtual Machine ID')
output vmId string = vm.id

@description('Virtual Machine name')
output vmName string = vm.name
