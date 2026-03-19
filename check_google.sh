#!/bin/bash

# 验证国家 / 地区定位
curl -Ls "https://www.youtube.com" | grep -o '"gl":"[A-Za-z]\{2\}"' | head -1

# 验证 IP 风控 / 信誉评级
curl -Is "https://www.google.com/search?q=ip" | grep -i -E "HTTP/1|HTTP/2"

# 原生 IP 鉴定
curl -Ls "https://www.youtube.com/premium" | grep -o "Premium is not available in your country"

# Google 学术风控鉴定
curl -Is "https://scholar.google.com/scholar?q=ip" | grep -i -E "HTTP/1|HTTP/2"

# 真实物理边缘定位
curl -Ls "https://redirector.googlevideo.com/report_mapping" | grep -o '=> .*'

# 底层连通性与透明代理防劫持检测
curl -Is "http://clients3.google.com/generate_204" | head -n 1

# EDNS 真实解析出口泄漏检测
curl -Ls "https://dns.google/resolve?name=o-o.myaddr.l.google.com&type=TXT" | grep -E -o '"data":\s*"[^"]+"'
