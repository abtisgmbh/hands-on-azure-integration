## Lab 1 - Logic Apps

![Architecture Lab-1](../docs/static/architecture-Lab-1.png)

### Calling the pizza chef from Postman

Create a POST request in Postman and add the following json body:

```json
{
  "customer_name": "{{$randomFirstName}}",
  "customer_address": "some.customer@outlook.com",
  "pizza_type": "Hawaii"
}
```