#!/bin/bash

find . -type f -exec dos2unix {} +

# find . -type f -exec touch -mt "$(date +%Y01010000)" {} +

find . -type f ! -name 'checksum.txt' -print0 |
    sort -z |
    xargs -0 sha256sum > checksum.txt
