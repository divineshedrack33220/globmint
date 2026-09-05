# ---- build (Flutter web) ----
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /src
COPY . .
RUN flutter pub get && flutter build web --no-tree-shake-icons --release

# ---- serve ----
FROM nginx:1.27-alpine
COPY --from=build /src/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf