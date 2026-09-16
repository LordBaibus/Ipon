<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);
$userId = $user['id'];

$scope = isset($body['scope']) ? trim((string) $body['scope']) : 'all';
$groupFilter = isset($body['group_id']) && $body['group_id'] !== null && $body['group_id'] !== ''
    ? (int) $body['group_id']
    : 0;

$select = 'SELECT p.id,
                  p.owner_id,
                  p.group_id,
                  p.name,
                  p.plan_type,
                  p.target_amount,
                  p.deadline,
                  p.notes,
                  p.created_at,
                  g.name AS group_name,
                  (SELECT COALESCE(SUM(c.amount), 0)
                     FROM plan_categories c
                    WHERE c.plan_id = p.id) AS allocated_total
             FROM plans p
        LEFT JOIN expense_groups g ON g.id = p.group_id ';

if ($groupFilter > 0) {
    require_group_member($conn, $groupFilter, $userId);

    $sql = $select . 'WHERE p.group_id = ? ORDER BY p.created_at DESC';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $groupFilter);
} elseif ($scope === 'personal') {
    $sql = $select . 'WHERE p.owner_id = ? AND p.group_id IS NULL
                      ORDER BY p.created_at DESC';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $userId);
} elseif ($scope === 'group') {
    $sql = $select . 'WHERE p.group_id IN (
                          SELECT gm.group_id FROM group_members gm WHERE gm.user_id = ?
                      )
                      ORDER BY p.created_at DESC';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $userId);
} else {
    $sql = $select . 'WHERE (p.owner_id = ? AND p.group_id IS NULL)
                         OR p.group_id IN (
                                SELECT gm.group_id FROM group_members gm WHERE gm.user_id = ?
                            )
                      ORDER BY p.created_at DESC';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('ii', $userId, $userId);
}

$stmt->execute();
$result = $stmt->get_result();

$plans = [];
while ($row = $result->fetch_assoc()) {
    $target = (float) $row['target_amount'];
    $allocated = (float) $row['allocated_total'];

    $plans[] = [
        'id'              => (int) $row['id'],
        'name'            => $row['name'],
        'plan_type'       => $row['plan_type'],
        'target_amount'   => round($target, 2),
        'allocated_total' => round($allocated, 2),
        'unallocated'     => round($target - $allocated, 2),
        'group_id'        => $row['group_id'] === null ? null : (int) $row['group_id'],
        'group_name'      => $row['group_name'],
        'is_personal'     => $row['group_id'] === null,
        'is_owner'        => ((int) $row['owner_id'] === $userId),
        'deadline'        => $row['deadline'],
        'notes'           => $row['notes'],
        'created_at'      => $row['created_at'],
    ];
}

$stmt->close();
$conn->close();

respond(true, '', $plans);