param receptionistName string
param servicebusConnectionName string = 'servicebus'
param serviceBusQueueName string = 'orders'

var logicAppResourceName = 'receptionist-${receptionistName}'
var location = resourceGroup().location

resource servicebusConnection 'Microsoft.Web/connections@2016-06-01' existing = {
  name: servicebusConnectionName
}

resource receptionist 'Microsoft.Logic/workflows@2019-05-01' = {
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
                delivery_zone: {
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

output resource string = receptionist.name
