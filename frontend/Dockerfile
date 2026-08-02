# --------------------------------------------------------------------------
# Track System - Frontend Dockerfile (multi-stage)
# Stage 1: build the React production bundle with Node
# Stage 2: serve the static assets with a lightweight Nginx image on port 80
# --------------------------------------------------------------------------

# ---- Stage 1: build ----
FROM node:20-alpine AS build

WORKDIR /app

# Cache dependency install separately from source changes
COPY package*.json ./
RUN npm install

COPY . .

# Produces static assets in /app/dist
RUN npm run build

# ---- Stage 2: runtime ----
FROM nginx:1.27-alpine AS runtime

# Remove default nginx static content and replace with our build output
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /app/dist /usr/share/nginx/html

# Custom server block: SPA fallback routing + /api reverse proxy to backend
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O- http://localhost:80/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
