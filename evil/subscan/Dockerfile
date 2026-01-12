FROM public.ecr.aws/docker/library/python:3.12-slim-bookworm AS dist
LABEL maintainer="honeok <i@honeok.com>"
WORKDIR /app
COPY . .
RUN set -ex \
    && python3 -m pip install --no-cache-dir -r requirements.txt --root-user-action=ignore \
    && chmod +x main.py
