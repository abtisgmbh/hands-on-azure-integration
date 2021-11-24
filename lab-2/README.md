## Lab 2 - Service Bus Queues

![Architecture Lab-1](../docs/static/architecture-Lab-2.png)

### Deploying the resources

```bash
az group create \
  --name 'pizza-lab-2'\
  --location westeurope \
  --tags workshop=azureIntegration

az deployment group create \
  --resource-group 'pizza-lab-2' \
  --template-file ./azuredeploy.bicep \
  --parameters pizzaChefName='michelangelo' \
      deliveryBoyName='fry' \
      receptionistName='meghan'
```

> **Note**: After the deployment succeeded, you need to manually authorize the o365 connection via the Azure portal (Edit API connection/Authorize/Save). You need to use an o365 account. Personal accounts without o365 license won't work.

### Calling the receptionist from Postman

Create a POST request in [Postman](https://www.postman.com/downloads/) and add the following json body:

```json
{
  "customer_name": "{{$randomFirstName}}",
  "customer_address": "some.customer@outlook.com",
  "pizza_type": "Tonno"
}
```

### Deploying additional pizza chefs

```bash
az deployment group create \
  --resource-group 'pizza-lab-2' \
  --template-file ./pizza-chef.bicep \
  --parameters pizzaChefName='raphael' \
      deliveryBoyName='fry'
```