<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../expense_helper.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);

$fields = validate_expense_fields($body);
$links = resolve_expense_links($conn, $body, (int) $user['id']);

$stmt = $conn->prepare(
    'INSERT INTO expenses
        (user_id, group_id, plan_id, plan_category_id, merchant, amount,
         category, expense_date, notes, source)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
);
$stmt->bind_param(
    'iiiisdssss',
    $user['id'],
    $links['group_id'],
    $links['plan_id'],
    $links['plan_category_id'],
    $fields['merchant'],
    $fields['amount'],
    $fields['category'],
    $fields['expense_date'],
    $fields['notes'],
    $fields['source']
);
$stmt->execute();
$expenseId = (int) $stmt->insert_id;
$stmt->close();
$stmt = $conn->prepare(
    'SELECT e.id, e.user_id, e.group_id, e.plan_id, e.plan_category_id,
            e.merchant, e.amount, e.category, e.expense_date, e.notes,
            e.source, e.created_at,
            u.full_name AS payer_name,
            g.name AS group_name
       FROM expenses e
       JOIN users u ON u.id = e.user_id
       LEFT JOIN expense_groups g ON g.id = e.group_id
      WHERE e.id = ?
      LIMIT 1'
);
$stmt->bind_param('i', $expenseId);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
$stmt->close();
$conn->close();

if (!$row) {
    respond(false, 'Expense saved but could not be reloaded.', null, 500);
}

respond(true, 'Expense saved.', format_expense_row($row, (int) $user['id']));