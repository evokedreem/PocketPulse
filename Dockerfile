FROM node:22-bookworm-slim

ENV EXPO_NO_TELEMETRY=1

WORKDIR /opt/pocketpulse
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

COPY deploy/docker-entrypoint.sh /usr/local/bin/pocketpulse-entrypoint
RUN chmod 0755 /usr/local/bin/pocketpulse-entrypoint

WORKDIR /app
EXPOSE 8081
ENTRYPOINT ["pocketpulse-entrypoint"]
CMD ["npx", "expo", "start", "--tunnel", "--port", "8081"]
