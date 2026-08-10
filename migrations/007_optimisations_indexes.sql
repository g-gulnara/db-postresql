--liquibase formatted sql

--changeset student:0007_indexes runInTransaction:false
CREATE INDEX IF NOT EXISTS idx_loans_reader_active 
ON loans (reader_id);

CREATE INDEX IF NOT EXISTS idx_book_genres_genre 
ON book_genres (genre_id);

CREATE INDEX IF NOT EXISTS idx_loans_due_date 
ON loans (due_date);

CREATE INDEX IF NOT EXISTS idx_book_items_status 
ON book_items (status_id);

CREATE INDEX IF NOT EXISTS idx_loans_reader_covering 
ON loans (reader_id, due_date, book_item_id);

--rollback DROP INDEX IF EXISTS idx_loans_reader_active;
--rollback DROP INDEX IF EXISTS idx_book_genres_genre;
--rollback DROP INDEX IF EXISTS idx_loans_due_date;
--rollback DROP INDEX IF EXISTS idx_book_items_status;
--rollback DROP INDEX IF EXISTS idx_loans_reader_covering;