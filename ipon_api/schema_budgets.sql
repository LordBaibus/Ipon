CREATE TABLE IF NOT EXISTS budgets (
    id               INT NOT NULL AUTO_INCREMENT,
    user_id          INT NOT NULL,
    group_id         INT NULL,
    limit_amount     DECIMAL(12,2) NOT NULL,
    cycle_start_day  TINYINT UNSIGNED NOT NULL DEFAULT 1,
    is_active        TINYINT(1) NOT NULL DEFAULT 1,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                         ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE budgets
    ADD CONSTRAINT fk_budgets_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;

ALTER TABLE budgets
    ADD CONSTRAINT fk_budgets_group
        FOREIGN KEY (group_id) REFERENCES expense_groups (id) ON DELETE CASCADE;

ALTER TABLE budgets
    ADD COLUMN group_scope_key INT
        GENERATED ALWAYS AS (IFNULL(group_id, 0)) STORED AFTER group_id;

CREATE UNIQUE INDEX uq_budgets_active_scope
    ON budgets (user_id, group_scope_key, is_active);

CREATE INDEX idx_budgets_group ON budgets (group_id);