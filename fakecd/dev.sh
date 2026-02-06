#!/bin/bash

curl -X POST "http://113.192.61.16:5000/deploy" \
    -H "Content-Type: application/json" \
    -H "Authorization: dI7DwPklJsVU76feF4AKN2Ob" \
    -d '{
        "image": "corentinth/it-tools",
        "tag": "2023.11.2-7d94e11"
    }'

curl -X POST "http://113.192.61.16:5000/deploy" \
    -H "Content-Type: application/json" \
    -H "Authorization: dI7DwPklJsVU76feF4AKN2Ob" \
    -d '{
        "image": "corentinth/it-tools",
        "tag": "2024.5.13-a0bc346"
    }'
