<?php
require_once __DIR__ . '/config.php';

function require_user(mysqli $conn, array $body): array
{
    $token = isset($body['token']) ? trim((string) $body['token']) : '';

    if ($token === '') {
        respond(false, 'You are not signed in.', null, 401);
    }

    $sql = 'SELECT id, full_name, email
              FROM users
             WHERE session_token = ?
               AND session_expires_at > NOW()
             LIMIT 1';

    $stmt = $conn->prepare($sql);
    $stmt->bind_param('s', $token);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    $stmt->close();

    if (!$user) {
        respond(false, 'Your session has expired. Please sign in again.', null, 401);
    }

    $user['id'] = (int) $user['id'];
    return $user;
}

function require_group_member(mysqli $conn, int $groupId, int $userId): array
{
    $sql = 'SELECT id, group_id, user_id, role
              FROM group_members
             WHERE group_id = ? AND user_id = ?
             LIMIT 1';

    $stmt = $conn->prepare($sql);
    $stmt->bind_param('ii', $groupId, $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    $membership = $result->fetch_assoc();
    $stmt->close();

    if (!$membership) {
        respond(false, 'You do not have access to this group.', null, 403);
    }

    $membership['id'] = (int) $membership['id'];
    $membership['group_id'] = (int) $membership['group_id'];
    $membership['user_id'] = (int) $membership['user_id'];
    return $membership;
}