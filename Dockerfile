FROM liquibase/liquibase:4.27.0

USER root

RUN apt-get update && apt-get install -y \
    curl \
    postgresql-client \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L https://jdbc.postgresql.org/download/postgresql-42.7.2.jar \
    -o /liquibase/lib/postgresql-42.7.2.jar

#seqwall
RUN curl -fsSL https://github.com/realkarych/seqwall/releases/download/v0.3.0/v0.3.0_seqwall_linux_amd64.tar.gz \
    | tar -xz -C /usr/local/bin seqwall \
    && chmod +x /usr/local/bin/seqwall

#для сидирования
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir faker psycopg2-binary

COPY migrations /migrations
COPY scripts /scripts
COPY seeds /seeds

RUN chmod +x /scripts/*.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]