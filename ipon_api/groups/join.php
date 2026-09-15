<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);

$inviteCode = isset($body['invite_code'])
    ? strtoupper(trim((string) $body['invite_code']))
    : '';

if ($inviteCode === '') {
    respond(false, 'Invite code is required.', null, 400);
}

$userId = $user['id'];

$stmt = $conn->prepare(
    'SELECT id, name, description, invite_code
       FROM expense_groups
      WHERE invite_code = ?
      LIMIT 1'
);
$stmt->bind_param('s', $inviteCode);
$stmt->execute();
$group = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$group) {
    respond(false, 'No group found with that invite code.', null, 404);
}

$groupId = (int) $group['id'];

$stmt = $conn->prepare(
    'SELECT id FROM group_members WHERE group_id = ? AND user_id = ? LIMIT 1'
);
$stmt->bind_param('ii', $groupId, $userId);
$stmt->execute();
$existing = $stmt->get_result()->fetch_assoc();
$stmt->close();

if ($existing) {
    respond(false, 'You are already a member of this group.', null, 409);
}

$stmt = $conn->prepare(
    "INSERT INTO group_members (group_id, user_id, role) VALUES (?, ?, 'member')"
);
$stmt->bind_param('ii', $groupId, $userId);

if (!$stmt->execute()) {
    $stmt->close();
    $conn->close();
    respond(false, 'Could not join the group. Please try again.', null, 500);
}
$stmt->close();

$stmt = $conn->prepare('SELECT COUNT(*) AS c FROM group_members WHERE group_id = ?');
$stmt->bind_param('i', $groupId);
$stmt->execute();
$countRow = $stmt->get_result()->fetch_assoc();
$stmt->close();

$conn->close();

respond(true, 'You have joined ' . $group['name'] . '.', [
    'id'           => $groupId,
    'name'         => $group['name'],
    'description'  => $group['description'],
    'invite_code'  => $group['invite_code'],
    'role'         => 'member',
    'member_count' => (int) $countRow['c'],
]);