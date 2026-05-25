# Build a partir da raiz do repo: docker compose build data-console
FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    bash \
    curl \
    docker.io \
    docker-compose \
    && pip3 install --break-system-packages --no-cache-dir requests pymongo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /console

COPY data-generator-console/package.json data-generator-console/package-lock.json ./
RUN npm ci --omit=dev

COPY data-generator-console/server.js ./
COPY data-generator-console/public ./public/

ENV PORT=3333
ENV PROJECT_ROOT=/workspace
ENV API_URL=http://api:8080

EXPOSE 3333

CMD ["node", "server.js"]
