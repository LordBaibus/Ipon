<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);

$groupId = null;
if (isset($body['group_id']) && $body['group_id'] !== null && $body['group_id'] !== '') {
    $groupId = (int) $body['group_id'];
    if ($groupId <= 0) {
        respond(false, 'Invalid group.', null, 400);
    }
    require_group_member($conn, $groupId, $user['id']);
}

if (!isset($body['limit_amount'])) {
    respond(false, 'A spending limit is required.', null, 400);
}

$limitAmount = round((float) $body['limit_amount'], 2);
if ($limitAmount <= 0) {
    respond(false, 'The spending limit must be greater than zero.', null, 400);
}
if ($limitAmount > 99999999.99) {
    respond(false, 'That spending limit is too large.', null, 400);
}

$cycleStartDay = isset($body['cycle_start_day']) && $body['cycle_start_day'] !== ''
    ? (int) $body['cycle_start_day']
    : 1;

if ($cycleStartDay < 1 || $cycleStartDay > 31) {
    respond(false, 'Cycle start day must be between 1 and 31.', null, 400);
}

$scopeKey = $groupId ?? 0;

$conn->begin_transaction();

try {
    $stmt = $conn->prepare(
        'SELECT id FROM budgets
          WHERE user_id = ? AND IFNULL(group_id, 0) = ? AND is_active = 1
          LIMIT 1
          FOR UPDATE'
    );
    $stmt->bind_param('ii', $user['id'], $scopeKey);
    $stmt->execute();
    $existing = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($existing) {
        $budgetId = (int) $existing['id'];
        $stmt = $conn->prepare(
            'UPDATE budgets
                SET limit_amount = ?, cycle_start_day = ?
              WHERE id = ?'
        );
        $stmt->bind_param('dii', $limitAmount, $cycleStartDay, $budgetId);
        $stmt->execute();
        $stmt->close();
    } else {
        $stmt = $conn->prepare(
            'INSERT INTO budgets (user_id, group_id, limit_amount, cycle_start_day, is_active)
             VALUES (?, ?, ?, ?, 1)'
        );
        $stmt->bind_param('iidi', $user['id'], $groupId, $limitAmount, $cycleStartDay);
        $stmt->execute();
        $budgetId = (int) $stmt->insert_id;
        $stmt->close();
    }

    $conn->commit();
} catch (\Throwable $e) {
    $conn->rollback();
    $conn->close();
    respond(false, 'Could not save the budget. Please try again.', null, 500);
}

$stmt = $conn->prepare(
    'SELECT id, user_id, group_id, limit_amount, cycle_start_day, created_at, updated_at
       FROM budgets
      WHERE id = ?
      LIMIT 1'
);
$stmt->bind_param('i', $budgetId);
$stmt->execute();
$saved = $stmt->get_result()->fetch_assoc();
$stmt->close();
$conn->close();

if (!$saved) {
    respond(false, 'Budget saved but could not be reloaded.', null, 500);
}

respond(true, 'Budget saved.', [
    'id'              => (int) $saved['id'],
    'group_id'        => $saved['group_id'] === null ? null : (int) $saved['group_id'],
    'limit_amount'    => round((float) $saved['limit_amount'], 2),
    'cycle_start_day' => (int) $saved['cycle_start_day'],
    'updated_at'      => $saved['updated_at'],
]);