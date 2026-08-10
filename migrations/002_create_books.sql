--liquibase formatted sql

--changeset author:2
CREATE TABLE authors (
    id        SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    biography TEXT
);

CREATE TABLE books (
    id             SERIAL PRIMARY KEY,
    title          VARCHAR(255) NOT NULL,
    publisher_id   INTEGER REFERENCES publishers(id),
    language_id    INTEGER REFERENCES languages(id),
    published_year INTEGER
);

CREATE TABLE book_authors (
    book_id   INTEGER REFERENCES books(id) ON DELETE CASCADE,
    author_id INTEGER REFERENCES authors(id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, author_id)
);

CREATE TABLE book_genres (
    book_id  INTEGER REFERENCES books(id) ON DELETE CASCADE,
    genre_id INTEGER REFERENCES genres(id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, genre_id)
);

--rollback DROP TABLE IF EXISTS authors CASCADE;
--rollback DROP TABLE IF EXISTS books CASCADE;
--rollback DROP TABLE IF EXISTS book_authors CASCADE;
--rollback DROP TABLE IF EXISTS book_genres CASCADE;
