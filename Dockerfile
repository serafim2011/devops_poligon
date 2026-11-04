# FROM caddy:2-builder-alpine AS builder
# RUN xcaddy build --output /usr/bin/caddy \
#     --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive \
#     --with github.com/caddy-dns/cloudflare \
#     --with github.com/mholt/caddy-ratelimit \
#     --with github.com/mholt/caddy-l4
# FROM caddy:2-alpine AS runner
# COPY --from=builder /usr/bin/caddy /usr/bin/caddy
# RUN caddy list-modules | grep "http.handlers.forward_proxy"


FROM python:3.12-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /build/wheels -r requirements.txt

FROM python:3.12-slim AS runner

WORKDIR /shop

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 1000 appgroup \
    && useradd -u 1000 -g appgroup -s /bin/sh -m appuser

COPY --from=builder /build/wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

COPY --chown=appuser:appgroup . .

USER appuser

EXPOSE 5000

CMD ["gunicorn", "shop.wsgi:application", "--bind", "0.0.0.0:5000", "--workers", "4"]