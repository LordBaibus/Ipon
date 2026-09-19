<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../budget_engine.php';

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

$scopeKey = $groupId ?? 0;

$stmt = $conn->prepare(
    'SELECT id, user_id, group_id, limit_amount, cycle_start_day, created_at, updated_at
       FROM budgets
      WHERE user_id = ? AND IFNULL(group_id, 0) = ? AND is_active = 1
      LIMIT 1'
);
$stmt->bind_param('ii', $user['id'], $scopeKey);
$stmt->execute();
$budget = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$budget) {
    $conn->close();
    respond(true, 'No budget set for this scope yet.', [
        'has_budget' => false,
        'group_id'   => $groupId,
    ]);
}

$budget['id'] = (int) $budget['id'];
$budget['user_id'] = (int) $budget['user_id'];
$budget['group_id'] = $budget['group_id'] === null ? null : (int) $budget['group_id'];
$budget['limit_amount'] = round((float) $budget['limit_amount'], 2);
$budget['cycle_start_day'] = (int) $budget['cycle_start_day'];
$today = date('Y-m-d');
$cycle = compute_budget_cycle($budget['cycle_start_day'], $today);

if ($groupId === null) {
    $stmt = $conn->prepare(
        'SELECT amount, expense_date
           FROM expenses
          WHERE user_id = ? AND group_id IS NULL
            AND expense_date BETWEEN ? AND ?'
    );
    $stmt->bind_param('iss', $user['id'], $cycle['start'], $cycle['end']);
} else {
    $stmt = $conn->prepare(
        'SELECT amount, expense_date
           FROM expenses
          WHERE group_id = ?
            AND expense_date BETWEEN ? AND ?'
    );
    $stmt->bind_param('iss', $groupId, $cycle['start'], $cycle['end']);
}
$stmt->execute();
$result = $stmt->get_result();
$expenses = [];
while ($row = $result->fetch_assoc()) {
    $expenses[] = $row;
}
$stmt->close();
$conn->close();

$pacing = compute_budget_pacing(
    $budget['limit_amount'],
    $cycle,
    $expenses,
    $today
);

respond(true, 'Budget loaded.', [
    'has_budget'      => true,
    'id'              => $budget['id'],
    'group_id'        => $budget['group_id'],
    'limit_amount'    => $budget['limit_amount'],
    'cycle_start_day' => $budget['cycle_start_day'],
    'updated_at'      => $budget['updated_at'],
    'pacing'          => $pacing,
]);