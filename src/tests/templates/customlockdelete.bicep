targetScope = 'subscription'

resource subLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'subscriptionLock'
  properties: {
    level: 'CanNotDelete'
    notes: 'This subscription is locked for Delete operations.'
  }
}
