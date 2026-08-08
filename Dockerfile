# Monorepo root Dockerfile for Fly / GitHub launch.
# Builds only the Node API from backend/ (ignores ios/, web/, etc.).
FROM node:22-bookworm-slim AS build
WORKDIR /app

COPY backend/package.json backend/package-lock.json ./
RUN npm ci

COPY backend/tsconfig.json ./
COPY backend/src ./src
RUN npx tsc -p tsconfig.json

FROM node:22-bookworm-slim
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8080
ENV HOST=0.0.0.0

COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev

COPY --from=build /app/dist ./dist

EXPOSE 8080
CMD ["node", "dist/index.js"]
