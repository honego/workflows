# fakecd

## example

POST请求触发

```shell
curl -X POST "http://192.168.1.1:5000/deploy" \
    -H "Content-Type: application/json" \
    -H "Authorization: K0N7NRjAC3HriVXFoHotjOClTqsJ5z7k" \
    -d '{
        "image": "nginx",
        "tag": "1.29.5-alpine"
    }'
```
