# Multi-Stage Dockerfile for Flutter Web Client
# Stage 1: Build Flutter Web application
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependency configuration
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source code and build for web
COPY . .
RUN flutter build web --release

# Stage 2: Minimal Nginx production runtime
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget -q --spider http://127.0.0.1/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
