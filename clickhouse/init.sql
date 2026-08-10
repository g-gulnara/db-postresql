CREATE TABLE IF NOT EXISTS fines_kafka (
    payload String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list  = 'library.public.fines',
    kafka_group_name  = 'clickhouse-library-consumer',
    kafka_format      = 'JSONAsString';

CREATE TABLE IF NOT EXISTS fines_data (
    id             Int32,
    loan_id        Nullable(Int32),
    amount         Nullable(Decimal(10,2)),
    payment_status Nullable(UInt8),
    op             String,
    ingested_at    DateTime DEFAULT now()
)
ENGINE = MergeTree()
ORDER BY (id, ingested_at);

CREATE MATERIALIZED VIEW IF NOT EXISTS fines_mv
TO fines_data
AS
SELECT
    JSONExtractInt(payload,    'after', 'id')             AS id,
    JSONExtractInt(payload,    'after', 'loan_id')        AS loan_id,
    JSONExtractFloat(payload,  'after', 'amount')         AS amount,
    JSONExtractUInt(payload,   'after', 'payment_status') AS payment_status,
    JSONExtractString(payload, 'op')                      AS op
FROM fines_kafka
WHERE JSONExtractString(payload, 'after') != '';

CREATE USER IF NOT EXISTS metabase_ro IDENTIFIED BY 'metabase_ro_password';
GRANT SELECT ON default.fines_data TO metabase_ro;
GRANT SELECT ON default.fines_kafka TO metabase_ro;