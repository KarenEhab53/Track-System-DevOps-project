# --------------------------------------------------------------------------
# Track System - Backend Dockerfile
# Node.js/Express API server. Single-stage runtime image (no build step
# needed for plain JS), optimized for small size and fast, cache-friendly
# rebuilds.
# --------------------------------------------------------------------------
FROM node:20-alpine

# Run as a non-root user for defense in depth
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /usr/src/app

# Copy only package manifests first so `npm install` is cached unless
# dependencies actually change.
COPY package*.json ./

# Install production dependencies only (no devDependencies) for a leaner
# image and faster installs.
RUN npm install --omit=dev

# Copy application source
COPY src ./src

# Environment variables (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD,
# PORT) are injected at runtime by Kubernetes from a Secret sourced from
# AWS Secrets Manager - never baked into the image.
ENV PORT=8000
ENV NODE_ENV=production

EXPOSE 8000

USER appuser

# Basic container-level healthcheck hitting the app's own /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "src/index.js"]
