--liquibase formatted sql

--changeset author:4
CREATE TABLE book_items (
    id               SERIAL PRIMARY KEY,
    book_id          INTEGER REFERENCES books(id),
    inventory_number VARCHAR(50) UNIQUE NOT NULL,
    status_id        INTEGER REFERENCES item_statuses(id),
    location_id      INTEGER REFERENCES locations(id)
);

CREATE TABLE loans (
    id           SERIAL PRIMARY KEY,
    book_item_id INTEGER REFERENCES book_items(id),
    reader_id    INTEGER REFERENCES readers(id),
    staff_id     INTEGER REFERENCES staff(id),
    issue_date   DATE,
    due_date     DATE
);

--rollback DROP TABLE IF EXISTS book_items CASCADE;
--rollback DROP TABLE IF EXISTS loans CASCADE;
