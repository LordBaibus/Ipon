<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../balance_engine.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);
$userId = $user['id'];

$groupId = isset($body['group_id']) ? (int) $body['group_id'] : 0;
if ($groupId <= 0) {
    respond(false, 'Group is required.', null, 400);
}

require_group_member($conn, $groupId, $userId);
$stmt = $conn->prepare(
    'SELECT gm.user_id, u.full_name
       FROM group_members gm
       JOIN users u ON u.id = gm.user_id
      WHERE gm.group_id = ?
      ORDER BY u.full_name ASC'
);
$stmt->bind_param('i', $groupId);
$stmt->execute();
$result = $stmt->get_result();

$members = [];
while ($row = $result->fetch_assoc()) {
    $members[] = [
        'user_id'   => (int) $row['user_id'],
        'full_name' => $row['full_name'],
    ];
}
$stmt->close();

if (count($members) === 0) {
    $conn->close();
    respond(true, '', [
        'group_id'    => $groupId,
        'total_spent' => 0.0,
        'per_member'  => [],
        'settlements' => [],
        'is_settled'  => true,
    ]);
}
$stmt = $conn->prepare(
    'SELECT user_id, COALESCE(SUM(amount), 0) AS paid
       FROM expenses
      WHERE group_id = ?
      GROUP BY user_id'
);
$stmt->bind_param('i', $groupId);
$stmt->execute();
$result = $stmt->get_result();

$paidByUserId = [];
$totalSpent = 0.0;
while ($row = $result->fetch_assoc()) {
    $paid = (float) $row['paid'];
    $paidByUserId[(int) $row['user_id']] = $paid;
    $totalSpent += $paid;
}
$stmt->close();
$conn->close();

$totalSpent = round($totalSpent, 2);

$balances = compute_group_balances($members, $paidByUserId, $totalSpent);
$settlements = settle_balances($balances);
foreach ($balances as $index => $row) {
    $balances[$index]['is_me'] = ($row['user_id'] === $userId);
}

respond(true, '', [
    'group_id'    => $groupId,
    'total_spent' => $totalSpent,
    'per_member'  => $balances,
    'settlements' => $settlements,
    'is_settled'  => count($settlements) === 0,
]);