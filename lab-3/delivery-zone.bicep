param deliveryZone string
param serviceBusTopicName string = 'pizza-delivery'

var serviceBusTopicSubscriptionName = 'delivery-zone-${deliveryZone}'
var serviceBusTopicSubscriptionFilterName = 'delivery-zone-filter-${deliveryZone}'

resource serviceBusTopic 'Microsoft.ServiceBus/namespaces/topics@2021-06-01-preview' existing = {
  name: serviceBusTopicName
}

resource serviceBusTopicSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-06-01-preview' = {
  parent: serviceBusTopic
  name: serviceBusTopicSubscriptionName
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

resource serviceBusTopicSubscriptionFilter 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2021-06-01-preview' = {
  parent: serviceBusTopicSubscription
  name: serviceBusTopicSubscriptionFilterName
  properties: {
    action: {}
    filterType: 'CorrelationFilter'
    correlationFilter: {
      properties: {
        delivery_zone: deliveryZone
      }
    }
  }
}

output subscriptionName string = serviceBusTopicSubscriptionName
