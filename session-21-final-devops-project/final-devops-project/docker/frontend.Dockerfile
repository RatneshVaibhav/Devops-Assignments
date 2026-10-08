# ShelfShare UI - build context: final-devops-project/
# ---- build stage: Node + Vite produce static files
FROM node:24-alpine AS build
WORKDIR /app
COPY application/frontend/package.json application/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY application/frontend/ ./
RUN npm run build

# ---- runtime stage: unprivileged nginx (uid 101, port 8080), no Node at all
FROM nginxinc/nginx-unprivileged:1.29-alpine
# the upstream image lags behind Alpine security fixes: patch the OS packages and drop
# curl, which the runtime never uses (Trivy found 42 fixable HIGH/CRITICAL CVEs)
USER root
RUN apk upgrade --no-cache && apk del --no-cache curl
USER 101
COPY docker/nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
# where nginx forwards /api - overridden per environment
ENV BACKEND_URL=http://backend:8000
EXPOSE 8080
