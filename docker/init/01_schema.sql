-- Лаба 1. Схема БД аренды оборудования. PostgreSQL 16. 3НФ.
-- CREATE DATABASE не пишем — БД создаёт Docker (equipment_rental).

-- 1. Пользователи
CREATE TABLE users (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   TEXT        NOT NULL,
    email       TEXT        NOT NULL UNIQUE,
    phone       TEXT,
    role        TEXT        NOT NULL DEFAULT 'customer'
                CHECK (role IN ('customer', 'employee', 'admin')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Клиенты-арендаторы (1:1 с users)
CREATE TABLE customers (
    user_id        BIGINT PRIMARY KEY
                   REFERENCES users(id) ON DELETE CASCADE,
    customer_type  TEXT   NOT NULL DEFAULT 'individual'
                   CHECK (customer_type IN ('individual', 'company')),
    company_name   TEXT,
    inn            TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Иерархия категорий (самоссылка parent_id)
CREATE TABLE equipment_categories (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id  BIGINT REFERENCES equipment_categories(id) ON DELETE RESTRICT,
    name       TEXT   NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Справочник моделей
CREATE TABLE equipment_models (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id  BIGINT NOT NULL REFERENCES equipment_categories(id) ON DELETE RESTRICT,
    brand        TEXT   NOT NULL,
    model_name   TEXT   NOT NULL,
    description  TEXT,
    UNIQUE (brand, model_name),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Единицы оборудования
CREATE TABLE equipment (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_id          BIGINT NOT NULL REFERENCES equipment_models(id) ON DELETE RESTRICT,
    inventory_number  TEXT   NOT NULL UNIQUE,
    condition         TEXT   NOT NULL DEFAULT 'good'
                      CHECK (condition IN ('excellent', 'good', 'fair', 'broken')),
    status            TEXT   NOT NULL DEFAULT 'available'
                      CHECK (status IN ('available', 'rented', 'maintenance', 'retired')),
    purchase_date     DATE,
    attributes        JSONB,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Остаток (1:1 с equipment)
CREATE TABLE stock (
    equipment_id  BIGINT PRIMARY KEY
                  REFERENCES equipment(id) ON DELETE CASCADE,
    quantity      INTEGER NOT NULL DEFAULT 1 CHECK (quantity >= 0),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Тарифы
CREATE TABLE tariffs (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_id     BIGINT NOT NULL REFERENCES equipment_models(id) ON DELETE CASCADE,
    period       TEXT   NOT NULL CHECK (period IN ('day', 'week', 'month')),
    price        NUMERIC(12,2) NOT NULL CHECK (price > 0),
    valid_from   DATE   NOT NULL DEFAULT CURRENT_DATE,
    valid_to     DATE,
    CHECK (valid_to IS NULL OR valid_to > valid_from)
);

-- 8. Заказы на аренду
CREATE TABLE rental_orders (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   BIGINT NOT NULL REFERENCES customers(user_id) ON DELETE RESTRICT,
    status        TEXT   NOT NULL DEFAULT 'created'
                  CHECK (status IN ('created', 'paid', 'active', 'returned', 'cancelled')),
    total_amount  NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    rental_start  DATE   NOT NULL,
    rental_end    DATE   NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (rental_end >= rental_start)
);

-- 9. Позиции заказа (M:N rental_orders ↔ equipment)
CREATE TABLE rental_order_items (
    order_id      BIGINT NOT NULL REFERENCES rental_orders(id) ON DELETE CASCADE,
    equipment_id  BIGINT NOT NULL REFERENCES equipment(id)    ON DELETE RESTRICT,
    tariff_id     BIGINT NOT NULL REFERENCES tariffs(id)       ON DELETE RESTRICT,
    quantity      INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price    NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (order_id, equipment_id)
);

-- 10. Платежи
CREATE TABLE payments (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    BIGINT NOT NULL REFERENCES rental_orders(id) ON DELETE CASCADE,
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    status      TEXT   NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    paid_at     TIMESTAMPTZ
);

-- 11. Журнал ТО
CREATE TABLE maintenance_records (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    equipment_id     BIGINT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
    maintenance_type TEXT   NOT NULL CHECK (maintenance_type IN ('routine', 'repair', 'inspection')),
    description      TEXT,
    cost             NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    performed_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 12. Акты повреждений (JSONB)
CREATE TABLE damage_reports (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    equipment_id   BIGINT NOT NULL REFERENCES equipment(id)     ON DELETE CASCADE,
    order_id       BIGINT          REFERENCES rental_orders(id) ON DELETE SET NULL,
    description    TEXT   NOT NULL,
    severity       TEXT   NOT NULL DEFAULT 'minor'
                   CHECK (severity IN ('minor', 'major', 'total')),
    damage_details JSONB,
    reported_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 13. Адреса
CREATE TABLE addresses (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  BIGINT NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE,
    city         TEXT   NOT NULL,
    street       TEXT   NOT NULL,
    house        TEXT   NOT NULL,
    apartment    TEXT,
    is_default   BOOLEAN NOT NULL DEFAULT FALSE
);

-- 14. Доставка (1:1 с заказом)
CREATE TABLE deliveries (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id         BIGINT NOT NULL UNIQUE REFERENCES rental_orders(id) ON DELETE CASCADE,
    address_id       BIGINT NOT NULL REFERENCES addresses(id) ON DELETE RESTRICT,
    delivery_status  TEXT   NOT NULL DEFAULT 'pending'
                     CHECK (delivery_status IN ('pending', 'shipped', 'delivered', 'failed')),
    delivery_date    TIMESTAMPTZ
);

-- 15. Отзывы
CREATE TABLE reviews (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       BIGINT NOT NULL REFERENCES users(id)     ON DELETE CASCADE,
    equipment_id  BIGINT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
    score         INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment       TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, equipment_id)
);