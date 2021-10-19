@description('Name of the pizza chef')
param pizzaChefName string = 'alan'

@description('Name of the delivery boy')
param deliveryBoyName string = 'bob'

@description('Name of the receptionist')
param receptionistName string = 'jim'

var receptionistResourceName = 'receptionist-${receptionistName}'
var location = resourceGroup().location
var suffix = uniqueString(resourceGroup().id)
var pizzaBakeryResourceName = 'pizzabakery${suffix}'
var thermoBoxName = 'thermo-box'
var serviceBusName = 'virtualpizzaorders${suffix}'
var serviceBusQueueName = 'orders'
var serviceBusTopicName = 'pizza-delivery'
var serviceBusTopicSubscriptionCityName = 'delivery-city'
var serviceBusTopicSubscriptionCityFilterName = 'delivery_zone_filter'

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

resource virtualpizzaorders 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource serviceBusRootManageSharedAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-06-01-preview' = {
  parent: virtualpizzaorders
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
  parent: virtualpizzaorders
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
  parent: virtualpizzaorders
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

resource serviceBusTopicSubscriptionCity 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-06-01-preview' = {
  parent: serviceBusTopic
  name: serviceBusTopicSubscriptionCityName
  properties: {
    isClientAffine: false
    lockDuration: 'PT30S'
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 1
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'P10675198DT2H48M5.477S'
  }
}

resource serviceBusTopicSubscriptionCityFilter 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2021-06-01-preview' = {
  parent: serviceBusTopicSubscriptionCity
  name: serviceBusTopicSubscriptionCityFilterName
  properties: {
    action: {}
    filterType: 'CorrelationFilter'
    correlationFilter: {
      properties: {
        delivery_zone: 'city'
      }
    }
  }
}

module pizzaChef 'pizza-chef.bicep' = {
  name: 'pizza-chef-deployment'
  params: {
    pizzaChefName: pizzaChefName
    servicebusConnectionName: servicebusConnection.name
    serviceBusQueueName: serviceBusQueue.name
    azureblobConnectionName: azureblobConnection.name
    deliveryBoyId: deliveryBoy.outputs.id
    azureblobConnectionId: azureblobConnection.id
    servicebusConnectionId: servicebusConnection.id
  }
}

module deliveryBoy 'delivery-boy.bicep' = {
  name: 'delivery-boy-deployment'
  params: {
    azureblobConnectionId: azureblobConnection.id
    deliveryBoyName: deliveryBoyName
    office365ConnectionId: office365Connection.id
    azureblobConnectionName: azureblobConnection.name
    office365ConnectionName: office365Connection.name
  }
}

resource receptionist 'Microsoft.Logic/workflows@2019-05-01' = {
  name: receptionistResourceName
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              properties: {
                customer_address: {
                  type: 'string'
                }
                customer_name: {
                  type: 'string'
                }
                pizza_type: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
      }
      actions: {
        Create_order: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            body: {
              ContentData: '@{base64(triggerBody())}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/@{encodeURIComponent(encodeURIComponent(\'${serviceBusQueueName}\'))}/messages'
            queries: {
              systemProperties: 'None'
            }
          }
        }
        Response: {
          runAfter: {
            Create_order: [
              'Succeeded'
            ]
          }
          type: 'Response'
          kind: 'Http'
          inputs: {
            body: {
              message: 'OK @{triggerBody()?[\'customer_name\']}, pizza @{triggerBody()?[\'pizza_type\']} coming up!'
            }
            statusCode: 200
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          servicebus: {
            connectionId: servicebusConnection.id
            connectionName: servicebusConnection.name
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'servicebus')
          }
        }
      }
    }
  }
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

output deliveryBoyId string = deliveryBoy.outputs.id
output azureblobConnectionId string = azureblobConnection.id
output servicebusConnectionId string = servicebusConnection.id
