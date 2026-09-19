<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);
$userId = (int) $user['id'];

$groupId = isset($body['group_id']) ? (int) $body['group_id'] : 0;
if ($groupId <= 0) {
    respond(false, 'Group is required.', null, 400);
}
require_group_member($conn, $groupId, $userId);

$stmt = $conn->prepare(
    'SELECT g.id, g.name, g.description, g.invite_code, g.owner_id,
            g.created_at,
            (SELECT COUNT(*) FROM group_members m WHERE m.group_id = g.id)
                AS member_count
       FROM expense_groups g
      WHERE g.id = ?
      LIMIT 1'
);
$stmt->bind_param('i', $groupId);
$stmt->execute();
$group = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$group) {
    respond(false, 'Group not found.', null, 404);
}
$stmt = $conn->prepare(
    'SELECT gm.user_id, gm.role, gm.joined_at,
            u.full_name, u.email,
            (SELECT COALESCE(SUM(e.amount), 0)
               FROM expenses e
              WHERE e.group_id = ? AND e.user_id = gm.user_id) AS total_paid
       FROM group_members gm
       JOIN users u ON u.id = gm.user_id
      WHERE gm.group_id = ?
      ORDER BY (gm.role = "owner") DESC, u.full_name ASC'
);
$stmt->bind_param('ii', $groupId, $groupId);
$stmt->execute();
$result = $stmt->get_result();
$members = [];
while ($row = $result->fetch_assoc()) {
    $members[] = [
        'user_id'    => (int) $row['user_id'],
        'full_name'  => $row['full_name'],
        'email'      => $row['email'],
        'role'       => $row['role'],
        'is_owner'   => $row['role'] === 'owner',
        'is_me'      => (int) $row['user_id'] === $userId,
        'joined_at'  => $row['joined_at'],
        'total_paid' => round((float) $row['total_paid'], 2),
    ];
}
$stmt->close();
$stmt = $conn->prepare(
    'SELECT p.id, p.name, p.plan_type, p.target_amount, p.deadline,
            p.notes, p.owner_id,
            (SELECT COALESCE(SUM(e.amount), 0)
               FROM expenses e
              WHERE e.plan_id = p.id) AS spent_total
       FROM plans p
      WHERE p.group_id = ?
      ORDER BY p.created_at DESC'
);
$stmt->bind_param('i', $groupId);
$stmt->execute();
$result = $stmt->get_result();
$plans = [];
while ($row = $result->fetch_assoc()) {
    $target = round((float) $row['target_amount'], 2);
    $spent = round((float) $row['spent_total'], 2);
    $plans[] = [
        'id'            => (int) $row['id'],
        'name'          => $row['name'],
        'plan_type'     => $row['plan_type'],
        'target_amount' => $target,
        'spent_total'   => $spent,
        'remaining'     => round($target - $spent, 2),
        'progress'      => $target > 0 ? min(1.0, $spent / $target) : 0.0,
        'deadline'      => $row['deadline'],
        'notes'         => $row['notes'],
        'is_owner'      => (int) $row['owner_id'] === $userId,
    ];
}
$stmt->close();
$conn->close();

respond(true, 'Group loaded.', [
    'id'           => (int) $group['id'],
    'name'         => $group['name'],
    'description'  => $group['description'],
    'invite_code'  => $group['invite_code'],
    'is_owner'     => (int) $group['owner_id'] === $userId,
    'member_count' => (int) $group['member_count'],
    'created_at'   => $group['created_at'],
    'members'      => $members,
    'plans'        => $plans,
]);