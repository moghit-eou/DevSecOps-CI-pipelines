FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

WORKDIR /app

COPY . .

USER non-root CMD ["sh", "-c", "echo 'Container is running' && sleep 3600"]
#CMD ["sh", "-c", "echo 'Container is running' && sleep 3600"]
