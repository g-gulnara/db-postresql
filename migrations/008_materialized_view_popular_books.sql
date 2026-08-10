--liquibase formatted sql

--changeset student:0008_matview splitStatements:false
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_popular_books AS
SELECT 
    b.id,
    b.title,
    COUNT(l.id) as loan_count,
    MAX(l.issue_date) as last_loan_date
FROM books b
JOIN book_items bi ON b.id = bi.book_id
JOIN loans l ON bi.id = l.book_item_id
GROUP BY b.id, b.title;

CREATE UNIQUE INDEX IF NOT EXISTS mv_popular_books_pk ON mv_popular_books (id);

CREATE OR REPLACE FUNCTION refresh_popular_books()
RETURNS void AS $func$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_popular_books;
END;
$func$ LANGUAGE plpgsql;

--rollback DROP FUNCTION IF EXISTS refresh_popular_books();
--rollback DROP INDEX IF EXISTS mv_popular_books_pk;
--rollback DROP MATERIALIZED VIEW IF EXISTS mv_popular_books;