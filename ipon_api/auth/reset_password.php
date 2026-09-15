<?php

require_once __DIR__ . '/../config.php';

$body = read_json_body();

$email       = isset($body['email']) ? strtolower(trim((string) $body['email'])) : '';
$code        = isset($body['code']) ? trim((string) $body['code']) : '';
$newPassword = isset($body['new_password']) ? (string) $body['new_password'] : '';

if ($email === '' || $code === '' || $newPassword === '') {
    respond(false, 'Email, code, and new password are all required.', null, 400);
}

if (strlen($newPassword) < 8) {
    respond(false, 'Password must be at least 8 characters long.', null, 400);
}

$conn = get_db();

$stmt = $conn->prepare('SELECT id FROM users WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    respond(false, 'That code is invalid or has expired.', null, 400);
}

$userId = (int) $user['id'];

$stmt = $conn->prepare(
    'SELECT id FROM password_resets
      WHERE user_id = ?
        AND code = ?
        AND consumed_at IS NULL
        AND expires_at > NOW()
      ORDER BY id DESC
      LIMIT 1'
);
$stmt->bind_param('is', $userId, $code);
$stmt->execute();
$reset = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$reset) {
    respond(false, 'That code is invalid or has expired. Request a new one.', null, 400);
}

$resetId = (int) $reset['id'];

$passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);

$stmt = $conn->prepare(
    'UPDATE users
        SET password_hash = ?, session_token = NULL, session_expires_at = NULL
      WHERE id = ?'
);
$stmt->bind_param('si', $passwordHash, $userId);
$stmt->execute();
$stmt->close();

$stmt = $conn->prepare('UPDATE password_resets SET consumed_at = NOW() WHERE id = ?');
$stmt->bind_param('i', $resetId);
$stmt->execute();
$stmt->close();

$conn->close();

respond(true, 'Password updated. You can now sign in with your new password.');