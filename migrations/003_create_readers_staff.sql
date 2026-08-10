--liquibase formatted sql

--changeset author:3
CREATE TABLE readers (
    id           SERIAL PRIMARY KEY,
    library_card VARCHAR(20) UNIQUE NOT NULL,
    full_name    VARCHAR(255),
    phone        VARCHAR(30),
    email        VARCHAR(255)
);

CREATE TABLE staff (
    id        SERIAL PRIMARY KEY,
    full_name VARCHAR(255),
    role_id   INTEGER REFERENCES staff_roles(id)
);

--rollback DROP TABLE IF EXISTS readers CASCADE;
--rollback DROP TABLE IF EXISTS staff CASCADE;
