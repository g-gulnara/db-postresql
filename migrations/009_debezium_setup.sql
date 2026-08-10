--liquibase formatted sql

--changeset student:0009_debezium_setup splitStatements:false

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'debezium_user') THEN
        CREATE USER debezium_user WITH PASSWORD 'debezium_password' REPLICATION SUPERUSER;
    END IF;
END $$;

GRANT CONNECT ON DATABASE library TO debezium_user;
GRANT USAGE ON SCHEMA public TO debezium_user;
GRANT SELECT ON TABLE public.fines TO debezium_user;

ALTER TABLE public.fines REPLICA IDENTITY DEFAULT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_publication WHERE pubname = 'debezium_fines_pub') THEN
        CREATE PUBLICATION debezium_fines_pub FOR TABLE public.fines;
    END IF;
END $$;

--rollback DROP PUBLICATION IF EXISTS debezium_fines_pub;
--rollback REASSIGN OWNED BY debezium_user TO library_user;
--rollback DROP OWNED BY debezium_user;
--rollback DROP USER IF EXISTS debezium_user;