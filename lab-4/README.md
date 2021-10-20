## Lab 4 - API Management

![Architecture Lab-1](../docs/static/architecture-Lab-4.png)

### Deployment

Deploy the lab:

```bash
rg=rg-pizza-lab4
az group create -n $rg -l westeurope
az deployment group create -f lab-4/azuredeploy.bicep -g $rg
```

Deploy additional pizza chefs:

```bash
rg=rg-pizza-lab3
az deployment group create -f lab-3/pizza-chef.bicep -g $rg --parameters pizzaChefName=michelangelo
```

Deploy additional delivery zones:

```bash
rg=rg-pizza-lab3
serviceBusName=$(az servicebus namespace list -g $rg -o table | awk 'NR>2{print $5}')
az deployment group create -f lab-3/delivery-zone.bicep -g $rg --parameters deliveryZone=suburb serviceBusName=$serviceBusName
```

Deploy additional delivery boys:

```bash
rg=rg-pizza-lab3
az deployment group create -f lab-3/delivery-boy.bicep -g $rg --parameters deliveryBoyName=fry deliveryZone=city

az deployment group create -f lab-3/delivery-boy.bicep -g $rg --parameters deliveryBoyName=bender deliveryZoneName=suburb
```

### Calling the pizza chef from Postman

Create a POST request in Postman and add the following json body:

```json
{
  "customer_name": "{{$randomFirstName}}",
  "customer_address": "some.customer@outlook.com",
  "pizza_type": "Hawaii",
  "delivery_zone": "city"
}
```