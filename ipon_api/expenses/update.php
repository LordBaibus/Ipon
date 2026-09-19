<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../expense_helper.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);
$userId = $user['id'];

$expenseId = isset($body['expense_id']) ? (int) $body['expense_id'] : 0;
if ($expenseId <= 0) {
    respond(false, 'Expense is required.', null, 400);
}
$existing = require_expense_access($conn, $expenseId, $userId);
if ($existing['user_id'] !== $userId) {
    respond(
        false,
        'Only the person who logged this expense can edit it.',
        null,
        403
    );
}

$fields = validate_expense_fields($body, $existing);
$linkInput = [];

$linkInput['group_id'] = array_key_exists('group_id', $body)
    ? $body['group_id']
    : $existing['group_id'];

$linkInput['plan_id'] = array_key_exists('plan_id', $body)
    ? $body['plan_id']
    : $existing['plan_id'];

$linkInput['plan_category_id'] = array_key_exists('plan_category_id', $body)
    ? $body['plan_category_id']
    : $existing['plan_category_id'];
if ($linkInput['plan_id'] === null || $linkInput['plan_id'] === '') {
    $linkInput['plan_category_id'] = null;
}

$links = resolve_expense_links($conn, $linkInput, $userId);
$stmt = $conn->prepare(
    'UPDATE expenses
        SET group_id = ?, plan_id = ?, plan_category_id = ?, merchant = ?,
            amount = ?, category = ?, expense_date = ?, notes = ?
      WHERE id = ?'
);

$stmt->bind_param(
    'iiisdsssi',
    $links['group_id'],
    $links['plan_id'],
    $links['plan_category_id'],
    $fields['merchant'],
    $fields['amount'],
    $fields['category'],
    $fields['expense_date'],
    $fields['notes'],
    $expenseId
);

if (!$stmt->execute()) {
    $stmt->close();
    $conn->close();
    respond(false, 'Could not update the expense. Please try again.', null, 500);
}
$stmt->close();
$sql = 'SELECT e.*,
               u.full_name  AS payer_name,
               g.name       AS group_name,
               p.name       AS plan_name,
               pc.label     AS category_label
          FROM expenses e
          JOIN users u            ON u.id  = e.user_id
     LEFT JOIN expense_groups g    ON g.id  = e.group_id
     LEFT JOIN plans p             ON p.id  = e.plan_id
     LEFT JOIN plan_categories pc  ON pc.id = e.plan_category_id
         WHERE e.id = ?
         LIMIT 1';

$stmt = $conn->prepare($sql);
$stmt->bind_param('i', $expenseId);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
$stmt->close();
$conn->close();

respond(true, 'Expense updated.', format_expense_row($row, $userId));