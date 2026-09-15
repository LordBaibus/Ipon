<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);

$userId = $user['id'];

$sql = 'SELECT g.id,
               g.name,
               g.description,
               g.invite_code,
               g.owner_id,
               gm.role,
               (SELECT COUNT(*) FROM group_members m WHERE m.group_id = g.id)
                   AS member_count
          FROM expense_groups g
          JOIN group_members gm ON gm.group_id = g.id
         WHERE gm.user_id = ?
         ORDER BY g.created_at DESC';

$stmt = $conn->prepare($sql);
$stmt->bind_param('i', $userId);
$stmt->execute();
$result = $stmt->get_result();

$groups = [];
while ($row = $result->fetch_assoc()) {
    $groups[] = [
        'id'           => (int) $row['id'],
        'name'         => $row['name'],
        'description'  => $row['description'],
        'invite_code'  => $row['invite_code'],
        'role'         => $row['role'],
        'member_count' => (int) $row['member_count'],
        'is_owner'     => ((int) $row['owner_id'] === $userId),
    ];
}

$stmt->close();
$conn->close();

respond(true, '', $groups);