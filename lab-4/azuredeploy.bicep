@description('Name of the pizza chef')
param pizzaChefName string = 'michelangelo'

@description('Name of the delivery boy')
param deliveryBoyName string = 'fry'

@description('Name of the receptionist')
param receptionistName string = 'meghan'

@description('Name of the delivery zone')
param deliveryZoneName string = 'city'

@allowed([
  'Developer'
  'Standard'
  'Premium'
])
param apiManagementSku string = 'Developer'
param apiManagementSkuPublisherEmail string = 'm.batsching@outlook.com'

var location = resourceGroup().location
var suffix = uniqueString(resourceGroup().id)

var pizzaBakeryResourceName = 'pizzabakery${suffix}'
var thermoBoxName = 'thermo-box'
var serviceBusName = 'virtualpizzaorders${suffix}'
var serviceBusQueueName = 'orders'
var serviceBusTopicName = 'pizza-delivery'
var apiManagementResourceName = 'virtualpizza-${suffix}'
var apiManagementPublisherName = 'Virtual Pizza Inc'


resource pizzaBakery 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: pizzaBakeryResourceName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2019-06-01' = {
  name: '${pizzaBakery.name}/default'
}

resource thermoBox 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${blobServices.name}/${thermoBoxName}'
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource serviceBusRootManageSharedAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-06-01-preview' = {
  parent: serviceBus
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2021-06-01-preview' = {
  parent: serviceBus
  name: serviceBusQueueName
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    enableBatchedOperations: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 1
    status: 'Active'
    enablePartitioning: false
    enableExpress: false
  }
}

resource serviceBusTopic 'Microsoft.ServiceBus/namespaces/topics@2021-06-01-preview' = {
  parent: serviceBus
  name: serviceBusTopicName
  properties: {
    defaultMessageTimeToLive: 'PT1H'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

module deliveryZone 'delivery-zone.bicep' = {
  name: 'delivery-zone-${deliveryZoneName}'
  params: {
    deliveryZone: deliveryZoneName
    serviceBusName: serviceBus.name
    serviceBusTopicName: serviceBusTopic.name
  }
  dependsOn: [
    serviceBus
    serviceBusTopic
  ]
}

module pizzaChef 'pizza-chef.bicep' = {
  name: 'pizza-chef-deployment'
  params: {
    pizzaChefName: pizzaChefName
    serviceBusQueueName: serviceBusQueue.name
    serviceBusTopicName: serviceBusTopic.name
    azureblobConnectionName: azureblobConnection.name
    servicebusConnectionName: servicebusConnection.name
    thermoBoxName: thermoBoxName
  }
  dependsOn: [
    servicebusConnection
    azureblobConnection
  ]
}

module deliveryBoy 'delivery-boy.bicep' = {
  name: 'delivery-boy-deployment'
  params: {
    deliveryBoyName: deliveryBoyName
    azureblobConnectionName: azureblobConnection.name
    office365ConnectionName: office365Connection.name
    servicebusConnectionName: servicebusConnection.name
    serviceBusTopicName: serviceBusTopicName
    deliveryZone: deliveryZoneName
  }
  dependsOn: [
    azureblobConnection
    office365Connection
    servicebusConnection
  ]
}

module receptionist 'receptionist.bicep' = {
  name: 'receptionist-deployment'
  params: {
    receptionistName: receptionistName
    servicebusConnectionName: servicebusConnection.name
  }
  dependsOn: [
    servicebusConnection
  ]
}

resource azureblobConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'azureblob'
  location: location
  properties: {
    displayName: 'azureblob'
    nonSecretParameterValues: {
      accountName: pizzaBakeryResourceName
    }
    api: {
      name: 'azureblob'
      displayName: 'Azure Blob Storage'
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
      type: 'Microsoft.Web/locations/managedApis'
    }
    parameterValues: {
      accountName: pizzaBakeryResourceName
      accessKey: listKeys(pizzaBakery.id, pizzaBakery.apiVersion).keys[0].value
    }
  }
}

resource office365Connection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'office365'
  location: location
  properties: {
    displayName: 'office365'
    customParameterValues: {}
    nonSecretParameterValues: {}
    api: {
      name: 'office365'
      displayName: 'Office 365 Outlook'
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
      type: 'Microsoft.Web/locations/managedApis'
    }
  }
}

resource servicebusConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'servicebus'
  location: location
  properties: {
    displayName: 'servicebus'
    api: {
      name: 'servicebus'
      displayName: 'Service Bus'
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'servicebus')
      type: 'Microsoft.Web/locations/managedApis'
    }
    parameterValues: {
      connectionString: listKeys(serviceBusRootManageSharedAccessKey.id, serviceBusRootManageSharedAccessKey.apiVersion).primaryConnectionString
    }
  }
}

module apim 'apim.bicep' = {
  name: 'apim-deploy'
  params: {
    apiManagementResourceName: apiManagementResourceName
    apiManagementPublisherName: apiManagementPublisherName
    apiManagementSku: apiManagementSku
    apiManagementSkuPublisherEmail: apiManagementSkuPublisherEmail
    location: location
    receptionistName: receptionistName
  }
  dependsOn: [
    receptionist
  ]
}
