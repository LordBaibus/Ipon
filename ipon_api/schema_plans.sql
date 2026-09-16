CREATE TABLE IF NOT EXISTS plans (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    owner_id      INT            NOT NULL,
    group_id      INT            DEFAULT NULL,
    name          VARCHAR(120)   NOT NULL,
    plan_type     VARCHAR(30)    NOT NULL DEFAULT 'custom',
    target_amount DECIMAL(12, 2) NOT NULL,
    deadline      DATE           DEFAULT NULL,
    notes         VARCHAR(255)   DEFAULT NULL,
    created_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_plans_owner (owner_id),
    KEY idx_plans_group (group_id),
    CONSTRAINT fk_plans_owner FOREIGN KEY (owner_id)
        REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_plans_group FOREIGN KEY (group_id)
        REFERENCES expense_groups (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS plan_categories (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    plan_id    INT            NOT NULL,
    label      VARCHAR(80)    NOT NULL,
    amount     DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    sort_order INT            NOT NULL DEFAULT 0,
    created_at TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_plan_categories_plan (plan_id),
    CONSTRAINT fk_plan_categories_plan FOREIGN KEY (plan_id)
        REFERENCES plans (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;