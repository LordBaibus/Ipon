CREATE TABLE IF NOT EXISTS plan_contributions (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    plan_id      INT            NOT NULL,
    user_id      INT            NOT NULL,
    weight       DECIMAL(8, 3)  NOT NULL DEFAULT 1.000,
    is_locked    TINYINT(1)     NOT NULL DEFAULT 0,
    share_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    paid_amount  DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    created_at   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_plan_user (plan_id, user_id),
    KEY idx_contrib_plan (plan_id),
    KEY idx_contrib_user (user_id),
    CONSTRAINT fk_contrib_plan FOREIGN KEY (plan_id)
        REFERENCES plans (id) ON DELETE CASCADE,
    CONSTRAINT fk_contrib_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;