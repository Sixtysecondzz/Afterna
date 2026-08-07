# Afterna API + worker image (deploy from this directory: `cd backend && fly deploy`)
FROM node:22-bookworm-slim

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev

COPY tsconfig.json ./
COPY src ./src

ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

# Default process is the API. Worker process overrides CMD in fly.toml.
CMD ["npx", "tsx", "src/index.ts"]
