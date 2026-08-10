FROM alpine:3.21

# pg_dump mc (MinIO client) python3
RUN apk add --no-cache \
    postgresql17-client \
    python3 \
    curl \
    bash

RUN curl -sSL https://dl.min.io/client/mc/release/linux-amd64/mc \
    -o /usr/local/bin/mc \
    && chmod +x /usr/local/bin/mc

COPY backup.sh /scripts/backup.sh
COPY entrypoint.sh /scripts/entrypoint.sh
COPY metrics_exporter.py /scripts/metrics_exporter.py

RUN chmod +x /scripts/backup.sh /scripts/entrypoint.sh

EXPOSE 9200

ENTRYPOINT ["/scripts/entrypoint.sh"]