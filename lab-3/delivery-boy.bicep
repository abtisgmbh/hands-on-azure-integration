param deliveryBoyName string
param azureblobConnectionId string
param office365ConnectionId string
param azureblobConnectionName string = 'azureblob'
param office365ConnectionName string = 'office365'

var logicAppResourceName = 'delivery-boy-${deliveryBoyName}'
var location = resourceGroup().location

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
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
            connectionId: azureblobConnectionId
            connectionName: azureblobConnectionName
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
          office365: {
            connectionId: office365ConnectionId
            connectionName: office365ConnectionName
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
          }
        }
      }
    }
  }
}

output id string = logicApp.id
