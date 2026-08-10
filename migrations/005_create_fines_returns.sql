--liquibase formatted sql

--changeset author:5
CREATE TABLE returns (
    id              SERIAL PRIMARY KEY,
    loan_id         INTEGER UNIQUE REFERENCES loans(id),
    return_date     DATE,
    staff_id        INTEGER REFERENCES staff(id),
    condition_after VARCHAR(100)
);

CREATE TABLE fines (
    id             SERIAL PRIMARY KEY,
    loan_id        INTEGER REFERENCES loans(id),
    amount         DECIMAL(10,2),
    payment_status BOOLEAN DEFAULT FALSE
);
--rollback DROP TABLE IF EXISTS returns CASCADE;
--rollback DROP TABLE IF EXISTS fines CASCADE;
