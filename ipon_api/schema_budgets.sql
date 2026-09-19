CREATE TABLE IF NOT EXISTS budgets (
    id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id          INT UNSIGNED NOT NULL,
    group_id         INT UNSIGNED NULL,
    limit_amount     DECIMAL(12,2) NOT NULL,
    cycle_start_day  TINYINT UNSIGNED NOT NULL DEFAULT 1,
    is_active        TINYINT(1) NOT NULL DEFAULT 1,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                         ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_budgets_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_budgets_group
        FOREIGN KEY (group_id) REFERENCES expense_groups (id) ON DELETE CASCADE,
    CONSTRAINT chk_budgets_limit_positive
        CHECK (limit_amount > 0),
    CONSTRAINT chk_budgets_cycle_day_range
        CHECK (cycle_start_day BETWEEN 1 AND 31)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE budgets
    ADD COLUMN group_scope_key INT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(group_id, 0)) STORED AFTER group_id;

CREATE UNIQUE INDEX uq_budgets_active_scope
    ON budgets (user_id, group_scope_key, is_active);

CREATE INDEX idx_budgets_group ON budgets (group_id);