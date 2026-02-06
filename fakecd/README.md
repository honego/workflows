# fakecd

## example

运行

```shell
tee docker-compose.yaml > /dev/null <<'EOF'
---
services:
  fakecd:
    image: fakecd
    container_name: fakecd
    restart: unless-stopped
    ports:
      - 5000:5000
    environment:
      - AUTH_TOKEN=K0N7NRjAC3HriVXFoHotjOClTqsJ5z7k # tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ../nginx:/app/nginx
      - ../redis:/app/redis
    network_mode: bridge
EOF
```

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
