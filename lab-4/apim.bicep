param apiManagementResourceName string
param location string = resourceGroup().location
param apiManagementSku string = 'Developer'
param apiManagementPublisherName string = 'abtis GmbH'
param apiManagementSkuPublisherEmail string
param receptionistName string = 'meghan'

resource receptionistLogicApp 'Microsoft.Logic/workflows@2019-05-01' existing = {
  name: 'receptionist-${receptionistName}' //TODO: Dont create names inside modules
}

resource apiManagementService 'Microsoft.ApiManagement/service@2020-06-01-preview' = {
  name: apiManagementResourceName
  location: location
  sku: {
    name: apiManagementSku
    capacity: 1
  }
  properties: {
    publisherName: apiManagementPublisherName
    publisherEmail: apiManagementSkuPublisherEmail
  }
}

var receptionistCallback = listCallbackUrl(receptionistLogicApp.id, receptionistLogicApp.apiVersion)

resource receptionistApi 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = {
  parent: apiManagementService
  name: 'receptionist'
  properties: {
    displayName: 'Virtual Pizza Receptionist'
    description: 'Deals with your orders.'
    serviceUrl: receptionistCallback.basePath
    path: 'orders'
    protocols: [
      'https'
    ]
  }
}

resource receptionistBackend 'Microsoft.ApiManagement/service/backends@2021-04-01-preview' = {
  parent: apiManagementService
  name: receptionistLogicApp.name
  properties: {
    description: 'Backend for Receptionist ${receptionistLogicApp.name}'
    url: receptionistCallback.basePath
    protocol: 'http'
    resourceId: '${environment().resourceManager}${receptionistLogicApp.id}'
  }
}

resource apiOperationNewOrder 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: 'newOrder'
  parent: receptionistApi
  properties: {
    displayName: 'Place an order'
    method: 'POST'
    urlTemplate: '/new'
    description: 'Place a pizza order.'
  }
}

resource apiOperationNewOrderPolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2021-04-01-preview' = {
  parent: apiOperationNewOrder
  name: 'policy'
  properties: {
    value: '<policies>\r\n  <inbound>\r\n    <base />\r\n    <set-backend-service backend-id="${receptionistBackend.name}" />\r\n    <rewrite-uri template="/triggers/manual/paths/invoke?api-version=${receptionistCallback.queries['api-version']}&amp;sp=${receptionistCallback.queries.sp}&amp;sv=${receptionistCallback.queries.sv}&amp;sig=${receptionistCallback.queries.sig}" />\r\n    <set-header id="apim-generated-policy" name="Ocp-Apim-Subscription-Key" exists-action="delete" />\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
    format: 'xml'
  }
}
