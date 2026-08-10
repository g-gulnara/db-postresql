-- name: get_reader_loans
SELECT 
    r.library_card,
    r.full_name,
    COUNT(l.id) as active_loans,
    MAX(l.due_date) as latest_due
FROM readers r
LEFT JOIN loans l ON r.id = l.reader_id 
    AND NOT EXISTS (SELECT 1 FROM returns WHERE loan_id = l.id)
WHERE r.library_card = 'LIB-000001'
GROUP BY r.id, r.library_card, r.full_name;

-- name: search_books_by_genre
SELECT 
    b.title,
    p.name as publisher,
    b.published_year,
    array_agg(g.name) as genres
FROM books b
JOIN book_genres bg ON b.id = bg.book_id
JOIN genres g ON bg.genre_id = g.id
JOIN publishers p ON b.publisher_id = p.id
WHERE g.name = 'Фантастика'
GROUP BY b.id, b.title, p.name, b.published_year
ORDER BY b.published_year DESC
LIMIT 50;

-- name: get_overdue_loans
SELECT 
    r.full_name,
    b.title,
    l.due_date,
    CURRENT_DATE - l.due_date as days_overdue
FROM loans l
JOIN readers r ON l.reader_id = r.id
JOIN book_items bi ON l.book_item_id = bi.id
JOIN books b ON bi.book_id = b.id
WHERE NOT EXISTS (SELECT 1 FROM returns WHERE loan_id = l.id)
  AND l.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;

-- name: book_availability_olap
SELECT 
    b.title,
    COUNT(bi.id) as total_items,
    COUNT(CASE WHEN s.status_name = 'available' THEN 1 END) as available,
    COUNT(CASE WHEN s.status_name = 'on_loan' THEN 1 END) as on_loan
FROM books b
JOIN book_items bi ON b.id = bi.book_id
JOIN item_statuses s ON bi.status_id = s.id
GROUP BY b.id, b.title
HAVING COUNT(bi.id) > 5
ORDER BY available DESC;

-- name: reader_history_log
SELECT 
    r.full_name,
    l.issue_date,
    COALESCE(ret.return_date::text, 'still_on_loan') as return_date,
    b.title
FROM readers r
JOIN loans l ON r.id = l.reader_id
JOIN book_items bi ON l.book_item_id = bi.id
JOIN books b ON bi.book_id = b.id
LEFT JOIN returns ret ON l.id = ret.loan_id
WHERE r.id = 1
ORDER BY l.issue_date DESC
LIMIT 100;

-- name: popular_books_analytic
SELECT 
    title,
    loan_count,
    RANK() OVER (ORDER BY loan_count DESC) as rank
FROM mv_popular_books
ORDER BY loan_count DESC
LIMIT 20;