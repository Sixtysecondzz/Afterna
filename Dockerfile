# Monorepo root Dockerfile for Fly / GitHub launch.
# Builds only the Node API from backend/ (ignores ios/, web/, etc.).
FROM node:22-bookworm-slim

WORKDIR /app

COPY backend/package.json backend/package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev

COPY backend/tsconfig.json ./
COPY backend/src ./src

ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

CMD ["npx", "tsx", "src/index.ts"]
