CREATE TABLE IF NOT EXISTS expenses (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT            NOT NULL,
    group_id         INT            DEFAULT NULL,
    plan_id          INT            DEFAULT NULL,
    plan_category_id INT            DEFAULT NULL,
    merchant         VARCHAR(120)   DEFAULT NULL,
    amount           DECIMAL(12, 2) NOT NULL,
    category         VARCHAR(60)    NOT NULL DEFAULT 'Uncategorized',
    expense_date     DATE           NOT NULL,
    notes            VARCHAR(255)   DEFAULT NULL,
    source           ENUM('manual', 'ocr') NOT NULL DEFAULT 'manual',
    created_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_expenses_user (user_id),
    KEY idx_expenses_group (group_id),
    KEY idx_expenses_plan (plan_id),
    KEY idx_expenses_category (plan_category_id),
    KEY idx_expenses_date (expense_date),
    CONSTRAINT fk_expenses_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_expenses_group FOREIGN KEY (group_id)
        REFERENCES expense_groups (id) ON DELETE CASCADE,
    CONSTRAINT fk_expenses_plan FOREIGN KEY (plan_id)
        REFERENCES plans (id) ON DELETE SET NULL,
    CONSTRAINT fk_expenses_plan_category FOREIGN KEY (plan_category_id)
        REFERENCES plan_categories (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;