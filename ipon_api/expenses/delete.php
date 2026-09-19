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

$expense = require_expense_access($conn, $expenseId, $userId);

$isOwnExpense = ($expense['user_id'] === $userId);
$isGroupOwner = false;

if (!$isOwnExpense && $expense['group_id'] !== null) {
    $stmt = $conn->prepare(
        'SELECT owner_id FROM expense_groups WHERE id = ? LIMIT 1'
    );
    $stmt->bind_param('i', $expense['group_id']);
    $stmt->execute();
    $group = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $isGroupOwner = $group && ((int) $group['owner_id'] === $userId);
}

if (!$isOwnExpense && !$isGroupOwner) {
    respond(
        false,
        'Only the person who logged this expense, or the group owner, can delete it.',
        null,
        403
    );
}

$stmt = $conn->prepare('DELETE FROM expenses WHERE id = ?');
$stmt->bind_param('i', $expenseId);

if (!$stmt->execute()) {
    $stmt->close();
    $conn->close();
    respond(false, 'Could not delete the expense. Please try again.', null, 500);
}

$stmt->close();
$conn->close();

respond(true, 'Expense deleted.', ['id' => $expenseId]);