--liquibase formatted sql
--changeset author:6 runOnChange:true splitStatements:false

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'monitoring_user') THEN
        CREATE USER monitoring_user WITH PASSWORD 'monitoring_password';
    END IF;
    
    IF NOT EXISTS (
        SELECT FROM pg_auth_members m
        JOIN pg_roles r ON m.roleid = r.oid
        JOIN pg_roles u ON m.member = u.oid
        WHERE r.rolname = 'pg_monitor' AND u.rolname = 'monitoring_user'
    ) THEN
        GRANT pg_monitor TO monitoring_user;
    END IF;
END $$;

GRANT CONNECT ON DATABASE library TO monitoring_user;

--rollback REVOKE CONNECT ON DATABASE library FROM monitoring_user;
--rollback REVOKE pg_monitor FROM monitoring_user;
--rollback DROP USER IF EXISTS monitoring_user;