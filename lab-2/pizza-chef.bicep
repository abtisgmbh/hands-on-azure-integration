param pizzaChefName string = 'raphael'
param thermoBoxName string = 'thermo-box'
param serviceBusQueueName string = 'orders'
param deliveryBoyName string = 'fry'

var logicAppResourceName = 'pizza-chef-${pizzaChefName}'
var location = resourceGroup().location

resource azureblobConnection 'Microsoft.Web/connections@2016-06-01' existing = {
  name: 'azureblob'
}

resource servicebusConnection 'Microsoft.Web/connections@2016-06-01' existing = {
  name: 'servicebus'
}

resource deliveryBoy 'Microsoft.Logic/workflows@2019-05-01' existing = {
  name: 'delivery-boy-${deliveryBoyName}'
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
        'When_a_message_is_received_in_a_queue_(auto-complete)': {
          recurrence: {
            frequency: 'Second'
            interval: 30
          }
          evaluatedRecurrence: {
            frequency: 'Second'
            interval: 30
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/@{encodeURIComponent(encodeURIComponent(\'${serviceBusQueueName}\'))}/messages/head'
            queries: {
              queueType: 'Main'
            }
          }
          runtimeConfiguration: {
            concurrency: {
              runs: 1
            }
          }
        }
      }
      actions: {
        Bake_the_pizza: {
          runAfter: {
            Parse_JSON: [
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
              customer_address: '@body(\'Parse_JSON\')?[\'customer_address\']'
              customer_name: '@body(\'Parse_JSON\')?[\'customer_name\']'
              pizza_path: '@body(\'Put_pizza_into_thermo-box\')?[\'Path\']'
              pizza_type: '@body(\'Parse_JSON\')?[\'pizza_type\']'
            }
            host: {
              triggerName: 'manual'
              workflow: {
                id: deliveryBoy.id
              }
            }
          }
        }
        Parse_JSON: {
          runAfter: {}
          type: 'ParseJson'
          inputs: {
            content: '@base64ToString(triggerBody()?[\'ContentData\'])'
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
        'Put_pizza_into_thermo-box': {
          runAfter: {
            Bake_the_pizza: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            body: 'Pizza @{body(\'Parse_JSON\')?[\'pizza_type\']}\n\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣤⣶⣶⣦⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⣿⣿⣿⣿⣷⣦⡀⠀⠀⠀⠀⠀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣷⣤⠀⠈⠙⢿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⠆⠰⠶⠀⠘⢿⣿⣿⣿⣿⣿⣆⠀⠀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⣿⠏⠀⢀⣠⣤⣤⣀⠙⣿⣿⣿⣿⣿⣷⡀⠀\n⠀⠀⠀⠀⠀⠀⠀⠀⢠⠋⢈⣉⠉⣡⣤⢰⣿⣿⣿⣿⣿⣷⡈⢿⣿⣿⣿⣿⣷⡀\n⠀⠀⠀⠀⠀⠀⠀⡴⢡⣾⣿⣿⣷⠋⠁⣿⣿⣿⣿⣿⣿⣿⠃⠀⡻⣿⣿⣿⣿⡇\n⠀⠀⠀⠀⠀⢀⠜⠁⠸⣿⣿⣿⠟⠀⠀⠘⠿⣿⣿⣿⡿⠋⠰⠖⠱⣽⠟⠋⠉⡇\n⠀⠀⠀⠀⡰⠉⠖⣀⠀⠀⢁⣀⠀⣴⣶⣦⠀⢴⡆⠀⠀⢀⣀⣀⣉⡽⠷⠶⠋⠀\n⠀⠀⠀⡰⢡⣾⣿⣿⣿⡄⠛⠋⠘⣿⣿⡿⠀⠀⣐⣲⣤⣯⠞⠉⠁⠀⠀⠀⠀⠀\n⠀⢀⠔⠁⣿⣿⣿⣿⣿⡟⠀⠀⠀⢀⣄⣀⡞⠉⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀\n⠀⡜⠀⠀⠻⣿⣿⠿⣻⣥⣀⡀⢠⡟⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀\n⢰⠁⠀⡤⠖⠺⢶⡾⠃⠀⠈⠙⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀\n⠈⠓⠾⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
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
              name: '@{body(\'Parse_JSON\')?[\'customer_name\']}/@{getFutureTime(0, \'Second\', \'HHmmss\')}-@{body(\'Parse_JSON\')?[\'pizza_type\']}.pizza'
              queryParametersSingleEncoded: true
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
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
