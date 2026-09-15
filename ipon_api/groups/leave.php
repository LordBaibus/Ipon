<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);

$groupId = isset($body['group_id']) ? (int) $body['group_id'] : 0;
$transferTo = isset($body['transfer_to_user_id'])
    ? (int) $body['transfer_to_user_id']
    : 0;

if ($groupId <= 0) {
    respond(false, 'Group is required.', null, 400);
}

$userId = $user['id'];

$membership = require_group_member($conn, $groupId, $userId);
$isOwner = ($membership['role'] === 'owner');

$stmt = $conn->prepare('SELECT COUNT(*) AS c FROM group_members WHERE group_id = ?');
$stmt->bind_param('i', $groupId);
$stmt->execute();
$memberCount = (int) $stmt->get_result()->fetch_assoc()['c'];
$stmt->close();

if ($isOwner && $memberCount > 1) {
    if ($transferTo <= 0) {
        respond(
            false,
            'You own this group. Choose another member to take over before leaving.',
            ['requires_transfer' => true],
            409
        );
    }
    $stmt = $conn->prepare(
        'SELECT id FROM group_members WHERE group_id = ? AND user_id = ? LIMIT 1'
    );
    $stmt->bind_param('ii', $groupId, $transferTo);
    $stmt->execute();
    $target = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$target) {
        respond(false, 'That person is not a member of this group.', null, 400);
    }

    $conn->begin_transaction();
    try {
        $stmt = $conn->prepare('UPDATE expense_groups SET owner_id = ? WHERE id = ?');
        $stmt->bind_param('ii', $transferTo, $groupId);
        $stmt->execute();
        $stmt->close();

        $stmt = $conn->prepare(
            "UPDATE group_members SET role = 'owner'
              WHERE group_id = ? AND user_id = ?"
        );
        $stmt->bind_param('ii', $groupId, $transferTo);
        $stmt->execute();
        $stmt->close();

        $stmt = $conn->prepare(
            'DELETE FROM group_members WHERE group_id = ? AND user_id = ?'
        );
        $stmt->bind_param('ii', $groupId, $userId);
        $stmt->execute();
        $stmt->close();

        $conn->commit();
    } catch (\Throwable $e) {
        $conn->rollback();
        $conn->close();
        respond(false, 'Could not leave the group. Please try again.', null, 500);
    }

    $conn->close();
    respond(true, 'You have left the group and ownership was transferred.', [
        'group_deleted' => false,
    ]);
}

if ($memberCount <= 1) {
    $stmt = $conn->prepare('DELETE FROM expense_groups WHERE id = ?');
    $stmt->bind_param('i', $groupId);
    $stmt->execute();
    $stmt->close();
    $conn->close();

    respond(true, 'You were the last member, so the group was deleted.', [
        'group_deleted' => true,
    ]);
}

$stmt = $conn->prepare('DELETE FROM group_members WHERE group_id = ? AND user_id = ?');
$stmt->bind_param('ii', $groupId, $userId);
$stmt->execute();
$stmt->close();
$conn->close();

respond(true, 'You have left the group.', ['group_deleted' => false]);