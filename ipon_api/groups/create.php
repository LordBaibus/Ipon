<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../helpers.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);

$name = isset($body['name']) ? trim((string) $body['name']) : '';
$description = isset($body['description']) ? trim((string) $body['description']) : '';

if ($name === '') {
    respond(false, 'Group name is required.', null, 400);
}

if (text_length($name) > 100) {
    respond(false, 'Group name is too long (100 characters max).', null, 400);
}

if (text_length($description) > 255) {
    respond(false, 'Description is too long (255 characters max).', null, 400);
}

function make_invite_code(): string
{
    $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    $code = '';
    for ($i = 0; $i < 8; $i++) {
        $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
    }
    return $code;
}

$inviteCode = '';
for ($attempt = 0; $attempt < 10; $attempt++) {
    $candidate = make_invite_code();

    $stmt = $conn->prepare('SELECT id FROM expense_groups WHERE invite_code = ? LIMIT 1');
    $stmt->bind_param('s', $candidate);
    $stmt->execute();
    $taken = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$taken) {
        $inviteCode = $candidate;
        break;
    }
}

if ($inviteCode === '') {
    respond(false, 'Could not generate an invite code. Please try again.', null, 500);
}

$ownerId = $user['id'];
$descriptionValue = ($description === '') ? null : $description;

$conn->begin_transaction();

try {
    $stmt = $conn->prepare(
        'INSERT INTO expense_groups (name, description, invite_code, owner_id)
         VALUES (?, ?, ?, ?)'
    );
    $stmt->bind_param('sssi', $name, $descriptionValue, $inviteCode, $ownerId);
    $stmt->execute();
    $groupId = (int) $conn->insert_id;
    $stmt->close();

    $stmt = $conn->prepare(
        "INSERT INTO group_members (group_id, user_id, role)
         VALUES (?, ?, 'owner')"
    );
    $stmt->bind_param('ii', $groupId, $ownerId);
    $stmt->execute();
    $stmt->close();

    $conn->commit();
} catch (\Throwable $e) {
    $conn->rollback();
    $conn->close();
    respond(false, 'Could not create the group. Please try again.', null, 500);
}

$conn->close();

respond(true, 'Group created.', [
    'id'           => $groupId,
    'name'         => $name,
    'description'  => $descriptionValue,
    'invite_code'  => $inviteCode,
    'role'         => 'owner',
    'member_count' => 1,
], 201);