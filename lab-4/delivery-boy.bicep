param deliveryBoyName string
param deliveryZone string
param servicebusConnectionName string = 'servicebus'
param azureblobConnectionName string = 'azureblob'
param office365ConnectionName string = 'office365'
param serviceBusTopicName string = 'pizza-delivery'

var serviceBusTopicSubscriptionName = 'delivery-zone-${deliveryZone}'
var logicAppResourceName = 'delivery-boy-${deliveryBoyName}'
var location = resourceGroup().location

resource azureblobConnection 'Microsoft.Web/connections@2016-06-01' existing = {
  name: azureblobConnectionName
}

resource servicebusConnection 'Microsoft.Web/connections@2016-06-01' existing = {
  name: servicebusConnectionName
}

resource office365Connection 'Microsoft.Web/connections@2016-06-01' existing = {
  name: office365ConnectionName
}

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
        'When_one_or_more_messages_arrive_in_a_topic_(auto-complete)': {
          recurrence: {
            frequency: 'Second'
            interval: 30
          }
          evaluatedRecurrence: {
            frequency: 'Second'
            interval: 30
          }
          splitOn: '@triggerBody()'
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/@{encodeURIComponent(encodeURIComponent(\'${serviceBusTopicName}\'))}/subscriptions/@{encodeURIComponent(\'${serviceBusTopicSubscriptionName}\')}/messages/batch/head'
            queries: {
              maxMessageCount: 1
              subscriptionType: 'Main'
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
                  Name: '@{body(\'Parse_JSON\')?[\'pizza_type\']}.pizza'
                }
              ]
              Body: '<p>Hi @{body(\'Parse_JSON\')?[\'customer_name\']}, here is your pizza @{body(\'Parse_JSON\')?[\'pizza_type\']}. Enjoy!</p>'
              Subject: 'Your pizza @{body(\'Parse_JSON\')?[\'pizza_type\']} is here!'
              To: '@body(\'Parse_JSON\')?[\'customer_address\']'
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
                path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'AccountNameFromSettings\'))}/files/@{encodeURIComponent(encodeURIComponent(body(\'Parse_JSON\')?[\'pizza_path\']))}'
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
                path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'AccountNameFromSettings\'))}/files/@{encodeURIComponent(encodeURIComponent(body(\'Parse_JSON\')?[\'pizza_path\']))}/content'
                queries: {
                  inferContentType: true
                }
              }
            }
          }
          runAfter: {
            Parse_JSON: [
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
            connectionName: azureblobConnectionName
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
          office365: {
            connectionId: office365Connection.id
            connectionName: office365ConnectionName
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
          }
          servicebus: {
            connectionId: servicebusConnection.id
            connectionName: servicebusConnectionName
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'servicebus')
          }
        }
      }
    }
  }
}

output id string = logicApp.id
