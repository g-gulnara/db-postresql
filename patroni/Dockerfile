FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    wget \
    gosu\
    gettext \
    && rm -rf /var/lib/apt/lists/*

# PostgreSQL 17
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y \
    postgresql-17 \
    postgresql-client-17 \
    && rm -rf /var/lib/apt/lists/*

# Patroni + etcd3
RUN python3 -m venv /opt/patroni \
    && /opt/patroni/bin/pip install --no-cache-dir \
    patroni[etcd3] \
    psycopg2-binary

ENV PATH="/opt/patroni/bin:$PATH"

COPY patroni.yml /etc/patroni/patroni.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /var/lib/postgresql/data \
    && chown -R postgres:postgres /var/lib/postgresql \
    && mkdir -p /var/run/postgresql \
    && chown -R postgres:postgres /var/run/postgresql

EXPOSE 5432 8008

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]