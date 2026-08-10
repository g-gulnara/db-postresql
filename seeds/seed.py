import os
import random
import psycopg2
from faker import Faker

app_env = os.getenv("APP_ENV", "dev")
if app_env == "prod":
    print("APP_ENV=prod — сидирование пропущено")
    exit(0)

SEED_COUNT = int(os.getenv("SEED_COUNT", "10"))
SEED_VERSION = os.getenv("SEED_VERSION", "v1")

print(f"Запуск сидирования: SEED_COUNT={SEED_COUNT}, SEED_VERSION={SEED_VERSION}")

fake = Faker("ru_RU")

conn = psycopg2.connect(
    host=os.getenv("POSTGRES_HOST", "postgres"),
    port=os.getenv("POSTGRES_PORT", "5432"),
    dbname=os.getenv("POSTGRES_DB"),
    user=os.getenv("POSTGRES_USER"),
    password=os.getenv("POSTGRES_PASSWORD"),
)
conn.autocommit = False
cur = conn.cursor()

try:
    #1

    languages = ["Русский", "English", "Français", "Deutsch", "Español"]
    for lang in languages:
        cur.execute("""
            INSERT INTO languages (name) VALUES (%s)
            ON CONFLICT DO NOTHING
        """, (lang,))

    publishers = [
        ("Эксмо", "Москва, ул. Правды, 1"),
        ("АСТ", "Москва, ул. Садовая, 5"),
        ("Питер", "Санкт-Петербург, Невский пр., 10"),
        ("O'Reilly", "Boston, MA"),
        ("Наука", "Москва, ул. Ленина, 3"),
    ]
    for name, address in publishers:
        cur.execute("""
            INSERT INTO publishers (name, address) VALUES (%s, %s)
            ON CONFLICT DO NOTHING
        """, (name, address))

    genres = [
        "Фантастика", "Детектив", "История", "Наука",
        "Биография", "Поэзия", "Роман", "Ужасы"
    ]
    for genre in genres:
        cur.execute("""
            INSERT INTO genres (name) VALUES (%s)
            ON CONFLICT (name) DO NOTHING
        """, (genre,))

    statuses = ["available", "on_loan", "reserved", "lost", "in_repair"]
    for status in statuses:
        cur.execute("""
            INSERT INTO item_statuses (status_name) VALUES (%s)
            ON CONFLICT DO NOTHING
        """, (status,))

    roles = ["librarian", "admin", "archivist"]
    for role in roles:
        cur.execute("""
            INSERT INTO staff_roles (role_name) VALUES (%s)
            ON CONFLICT DO NOTHING
        """, (role,))

    for _ in range(20):
        cur.execute("""
            INSERT INTO locations (hall_number, shelf_number)
            VALUES (%s, %s)
        """, (random.randint(1, 5), random.randint(1, 30)))

    conn.commit()
    print("Справочники заполнены")

    #riders staff

    cur.execute("SELECT COUNT(*) FROM readers")
    readers_count = cur.fetchone()[0]

    if readers_count < SEED_COUNT * 5:
        for i in range(1, SEED_COUNT * 5 + 1):
            cur.execute("""
                INSERT INTO readers (library_card, full_name, phone, email)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (library_card) DO NOTHING
            """, (
                f"LIB-{i:06d}",
                fake.name(),
                fake.phone_number(),
                fake.email(),
            ))

    cur.execute("SELECT COUNT(*) FROM staff")
    staff_count = cur.fetchone()[0]

    if staff_count < SEED_COUNT * 3:
        cur.execute("SELECT id FROM staff_roles")
        role_ids = [row[0] for row in cur.fetchall()]
        for _ in range(SEED_COUNT * 3):
            cur.execute("""
                INSERT INTO staff (full_name, role_id)
                VALUES (%s, %s)
            """, (fake.name(), random.choice(role_ids)))

    conn.commit()
    print("Читатели и сотрудники заполнены")

    #books

    cur.execute("SELECT COUNT(*) FROM books")
    books_count = cur.fetchone()[0]

    if books_count < SEED_COUNT * 10:
        for _ in range(SEED_COUNT * 3):
            cur.execute("""
                INSERT INTO authors (full_name, biography)
                VALUES (%s, %s)
            """, (fake.name(), fake.text(max_nb_chars=300)))

        cur.execute("SELECT id FROM publishers")
        publisher_ids = [row[0] for row in cur.fetchall()]
        cur.execute("SELECT id FROM languages")
        language_ids = [row[0] for row in cur.fetchall()]
        cur.execute("SELECT id FROM authors")
        author_ids = [row[0] for row in cur.fetchall()]
        cur.execute("SELECT id FROM genres")
        genre_ids = [row[0] for row in cur.fetchall()]

        for _ in range(SEED_COUNT * 10):
            cur.execute("""
                INSERT INTO books (title, publisher_id, language_id, published_year)
                VALUES (%s, %s, %s, %s)
                RETURNING id
            """, (
                fake.catch_phrase(),
                random.choice(publisher_ids),
                random.choice(language_ids),
                random.randint(1970, 2024),
            ))
            book_id = cur.fetchone()[0]

            # book_authors
            for author_id in random.sample(author_ids, k=random.randint(1, 3)):
                cur.execute("""
                    INSERT INTO book_authors (book_id, author_id)
                    VALUES (%s, %s)
                    ON CONFLICT DO NOTHING
                """, (book_id, author_id))

            # book_genres
            for genre_id in random.sample(genre_ids, k=random.randint(1, 2)):
                cur.execute("""
                    INSERT INTO book_genres (book_id, genre_id)
                    VALUES (%s, %s)
                    ON CONFLICT DO NOTHING
                """, (book_id, genre_id))

        # book_items: 15 * SEED_COUNT
        cur.execute("SELECT id FROM books")
        book_ids = [row[0] for row in cur.fetchall()]
        cur.execute("SELECT id FROM item_statuses")
        status_ids = [row[0] for row in cur.fetchall()]
        cur.execute("SELECT id FROM locations")
        location_ids = [row[0] for row in cur.fetchall()]

        for i in range(1, SEED_COUNT * 15 + 1):
            cur.execute("""
                INSERT INTO book_items (book_id, inventory_number, status_id, location_id)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (inventory_number) DO NOTHING
            """, (
                random.choice(book_ids),
                f"INV-{i:08d}",
                random.choice(status_ids),
                random.choice(location_ids),
            ))

    conn.commit()
    print("Книги и экземпляры заполнены")

    #4

    cur.execute("SELECT COUNT(*) FROM loans")
    loans_count = cur.fetchone()[0]

    if loans_count < SEED_COUNT * 20:
        cur.execute("SELECT id FROM book_items")
        book_item_ids = [row[0] for row in cur.fetchall()]
        cur.execute("SELECT id FROM readers")
        reader_ids = [row[0] for row in cur.fetchall()]
        cur.execute("SELECT id FROM staff")
        staff_ids = [row[0] for row in cur.fetchall()]

        for _ in range(SEED_COUNT * 20):
            issue_date = fake.date_between(start_date="-2y", end_date="today")
            due_date = fake.date_between(
                start_date=issue_date,
                end_date="+14d"
            )
            cur.execute("""
                INSERT INTO loans (book_item_id, reader_id, staff_id, issue_date, due_date)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
            """, (
                random.choice(book_item_ids),
                random.choice(reader_ids),
                random.choice(staff_ids),
                issue_date,
                due_date,
            ))
            loan_id = cur.fetchone()[0]

            # ~50% займов — возвращены
            if random.random() > 0.5:
                return_date = fake.date_between(
                    start_date=issue_date,
                    end_date="today"
                )
                cur.execute("""
                    INSERT INTO returns (loan_id, return_date, staff_id, condition_after)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (loan_id) DO NOTHING
                """, (
                    loan_id,
                    return_date,
                    random.choice(staff_ids),
                    random.choice(["good", "fair", "damaged"]),
                ))

            # ~20% займов — штраф
            if random.random() > 0.8:
                cur.execute("""
                    INSERT INTO fines (loan_id, amount, payment_status)
                    VALUES (%s, %s, %s)
                """, (
                    loan_id,
                    round(random.uniform(50, 500), 2),
                    random.choice([True, False]),
                ))

    conn.commit()
    print("Выдачи, возвраты и штрафы заполнены")
    print("=== Сидирование завершено ===")

except Exception as e:
    conn.rollback()
    print(f"Ошибка: {e}")
    raise
finally:
    cur.close()
    conn.close()