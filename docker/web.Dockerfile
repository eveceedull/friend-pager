FROM debian:bookworm-slim AS build
ENV CI=true DO_NOT_TRACK=1 FLUTTER_SUPPRESS_ANALYTICS=true DASH__SUPPRESS_ANALYTICS=true DEBIAN_FRONTEND=noninteractive PATH=/opt/flutter/bin:$PATH
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip libglu1-mesa python3 \
    && rm -rf /var/lib/apt/lists/*
RUN git init --initial-branch=stable /opt/flutter \
    && git -C /opt/flutter remote add origin https://github.com/flutter/flutter.git \
    && git -C /opt/flutter fetch --depth=1 origin refs/tags/3.47.8:refs/tags/3.47.8 \
    && test "$(git -C /opt/flutter rev-parse '3.47.8^{commit}')" = 737ba8f885dc774b53b442759999a312c9461e4e \
    && git -C /opt/flutter checkout -B stable 737ba8f885dc774b53b442759999a312c9461e4e \
    && flutter config --no-analytics
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY lib ./lib
COPY assets ./assets
COPY tool/generate-runners.sh tool/flutter_bootstrap.js ./tool/
RUN bash tool/generate-runners.sh web \
    && flutter build web --release --no-web-resources-cdn --no-pub

FROM nginx:1.28.0-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
