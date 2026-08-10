--liquibase formatted sql

--changeset author:1
CREATE TABLE languages (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE publishers (
    id      SERIAL PRIMARY KEY,
    name    VARCHAR(255),
    address VARCHAR(255)
);

CREATE TABLE genres (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE item_statuses (
    id          SERIAL PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL
);

CREATE TABLE staff_roles (
    id        SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL
);

CREATE TABLE locations (
    id           SERIAL PRIMARY KEY,
    hall_number  INTEGER,
    shelf_number INTEGER
);

--rollback DROP TABLE IF EXISTS languages;
--rollback DROP TABLE IF EXISTS publishers;
--rollback DROP TABLE IF EXISTS genres;
--rollback DROP TABLE IF EXISTS item_statuses;
--rollback DROP TABLE IF EXISTS staff_roles CASCADE;
--rollback DROP TABLE IF EXISTS locations CASCADE;
