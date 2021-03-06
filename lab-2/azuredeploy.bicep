@description('Name of the pizza chef')
param pizzaChefName string = 'michelangelo'

@description('Name of the delivery boy')
param deliveryBoyName string = 'fry'

@description('Name of the receptionist')
param receptionistName string = 'meghan'


var deliveryBoyResourceName = 'delivery-boy-${deliveryBoyName}'
var receptionistResourceName = 'receptionist-${receptionistName}'
var location = resourceGroup().location
var suffix = uniqueString(resourceGroup().id)
var pizzaBakeryResourceName = 'pizzabakery${suffix}'
var thermoBoxName = 'thermo-box'
var serviceBusName = 'virtualpizzaorders${suffix}'
var serviceBusQueueName = 'orders'

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
    name: 'Basic'
    tier: 'Basic'
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

module pizzaChef 'pizza-chef.bicep' = {
  name: 'pizza-chef-deployment'
  params: {
    pizzaChefName: pizzaChefName
    serviceBusQueueName: serviceBusQueue.name
    deliveryBoyName: deliveryBoyName
  }
  dependsOn: [
    servicebusConnection
    azureblobConnection
    deliveryBoy
  ]
}

resource deliveryBoy 'Microsoft.Logic/workflows@2019-05-01' = {
  name: deliveryBoyResourceName
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
                pizza_path: {
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
        Deliver_pizza_to_customer: {
          runAfter: {
            Drive_to_customer_address: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            body: {
              Attachments: [
                {
                  ContentBytes: '@{base64(body(\'Get_blob_content_(V2)\'))}'
                  Name: '@{triggerBody()?[\'pizza_type\']}.pizza'
                }
              ]
              Body: '<p>Hi @{triggerBody()?[\'customer_name\']}, here is your pizza @{triggerBody()?[\'pizza_type\']}. Enjoy!</p>'
              Subject: 'Your pizza @{triggerBody()?[\'pizza_type\']} is here!'
              To: '@triggerBody()?[\'customer_address\']'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
          }
        }
        Drive_to_customer_address: {
          runAfter: {
            'Take_pizza_from_thermo-box': [
              'Succeeded'
            ]
          }
          type: 'Wait'
          inputs: {
            interval: {
              count: 30
              unit: 'Second'
            }
          }
        }
        'OK_Chef!': {
          runAfter: {}
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
          }
        }
        'Take_pizza_from_thermo-box': {
          actions: {
            Delete_blob: {
              runAfter: {
                'Get_blob_content_(V2)': [
                  'Succeeded'
                ]
              }
              type: 'ApiConnection'
              inputs: {
                headers: {
                  SkipDeleteIfFileNotFoundOnServer: false
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
                  }
                }
                method: 'delete'
                path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'AccountNameFromSettings\'))}/files/@{encodeURIComponent(encodeURIComponent(triggerBody()?[\'pizza_path\']))}'
              }
            }
            'Get_blob_content_(V2)': {
              runAfter: {}
              type: 'ApiConnection'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
                  }
                }
                method: 'get'
                path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'AccountNameFromSettings\'))}/files/@{encodeURIComponent(encodeURIComponent(triggerBody()?[\'pizza_path\']))}/content'
                queries: {
                  inferContentType: true
                }
              }
            }
          }
          runAfter: {
            'OK_Chef!': [
              'Succeeded'
            ]
          }
          type: 'Scope'
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          azureblob: {
            connectionId: azureblobConnection.id
            connectionName: azureblobConnection.name
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
          office365: {
            connectionId: office365Connection.id
            connectionName: office365Connection.name
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
          }
        }
      }
    }
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

output deliveryBoyId string = deliveryBoy.id
output azureblobConnectionId string = azureblobConnection.id
output servicebusConnectionId string = servicebusConnection.id
