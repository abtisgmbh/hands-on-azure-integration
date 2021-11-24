@description('Name of the pizza chef')
param pizzaChefName string = 'michelangelo'

@description('Name of the delivery boy')
param deliveryBoyName string = 'fry'

var logicAppResourceName = 'pizza-chef-${pizzaChefName}'
var deliveryBoyResourceName = 'delivery-boy-${deliveryBoyName}'
var location = resourceGroup().location
var pizzaBakeryResourceName = 'pizzabakery${uniqueString(resourceGroup().id)}'
var thermoBoxName = 'thermo-box' 

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

resource pizzaChef 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppResourceName
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
        Bake_the_pizza: {
          runAfter: {
            Response: [
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
        Notify_the_delivery_boy: {
          runAfter: {
            'Put_pizza_into_thermo-box': [
              'Succeeded'
            ]
          }
          type: 'Workflow'
          inputs: {
            body: {
              customer_address: '@triggerBody()?[\'customer_address\']'
              customer_name: '@triggerBody()?[\'customer_name\']'
              pizza_path: '@body(\'Put_pizza_into_thermo-box\')?[\'Path\']'
              pizza_type: '@triggerBody()?[\'pizza_type\']'
            }
            host: {
              triggerName: 'manual'
              workflow: {
                id: deliveryBoy.id
              }
            }
          }
        }
        'Put_pizza_into_thermo-box': {
          runAfter: {
            Bake_the_pizza: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            body: 'Pizza @{triggerBody()?[\'pizza_type\']}\n\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣤⣶⣶⣦⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⣿⣿⣿⣿⣷⣦⡀⠀⠀⠀⠀⠀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣷⣤⠀⠈⠙⢿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⠆⠰⠶⠀⠘⢿⣿⣿⣿⣿⣿⣆⠀⠀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⣿⠏⠀⢀⣠⣤⣤⣀⠙⣿⣿⣿⣿⣿⣷⡀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⢠⠋⢈⣉⠉⣡⣤⢰⣿⣿⣿⣿⣿⣷⡈⢿⣿⣿⣿⣿⣷⡀\n⠀⠀⠀⠀⠀⠀⠀⡴⢡⣾⣿⣿⣷⠋⠁⣿⣿⣿⣿⣿⣿⣿⠃⠀⡻⣿⣿⣿⣿⡇\n⠀⠀⠀⠀⠀⢀⠜⠁⠸⣿⣿⣿⠟⠀⠀⠘⠿⣿⣿⣿⡿⠋⠰⠖⠱⣽⠟⠋⠉⡇\n⠀⠀⠀⠀⡰⠉⠖⣀⠀⠀⢁⣀⠀⣴⣶⣦⠀⢴⡆⠀⠀⢀⣀⣀⣉⡽⠷⠶⠋⠀\n⠀⠀⠀⡰⢡⣾⣿⣿⣿⡄⠛⠋⠘⣿⣿⡿⠀⠀⣐⣲⣤⣯⠞⠉⠁⠀⠀⠀⠀⠀\n⠀⢀⠔⠁⣿⣿⣿⣿⣿⡟⠀⠀⠀⢀⣄⣀⡞⠉⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀\n⠀⡜⠀⠀⠻⣿⣿⠿⣻⣥⣀⡀⢠⡟⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀\n⢰⠁⠀⡤⠖⠺⢶⡾⠃⠀⠈⠙⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀\n⠈⠓⠾⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
            headers: {
              ReadFileMetadataFromServer: true
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'AccountNameFromSettings\'))}/files'
            queries: {
              folderPath: '/${thermoBoxName}'
              name: '@{triggerBody()?[\'customer_name\']}/@{getFutureTime(0,\'Second\',\'HHmmss\')}-@{triggerBody()?[\'pizza_type\']}.pizza'
              queryParametersSingleEncoded: true
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
        Response: {
          runAfter: {}
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
          azureblob: {
            connectionId: azureblobConnection.id
            connectionName: azureblobConnection.name
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
        }
      }
    }
  }
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
