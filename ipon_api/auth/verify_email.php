<?php

require_once __DIR__ . '/../config.php';

$body = read_json_body();

$email = isset($body['email']) ? strtolower(trim((string) $body['email'])) : '';
$code  = isset($body['code']) ? trim((string) $body['code']) : '';

if ($email === '' || $code === '') {
    respond(false, 'Email and verification code are required.', null, 400);
}

$conn = get_db();

$stmt = $conn->prepare('SELECT id, is_verified FROM users WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    respond(false, 'No account found with that email address.', null, 404);
}

$userId = (int) $user['id'];

if ((int) $user['is_verified'] === 1) {
    respond(true, 'This account is already verified. You can sign in.');
}

$stmt = $conn->prepare(
    'SELECT id FROM email_verifications
      WHERE user_id = ?
        AND code = ?
        AND consumed_at IS NULL
        AND expires_at > NOW()
      ORDER BY id DESC
      LIMIT 1'
);
$stmt->bind_param('is', $userId, $code);
$stmt->execute();
$verification = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$verification) {
    respond(false, 'That code is invalid or has expired. Request a new one.', null, 400);
}

$verificationId = (int) $verification['id'];

$stmt = $conn->prepare('UPDATE email_verifications SET consumed_at = NOW() WHERE id = ?');
$stmt->bind_param('i', $verificationId);
$stmt->execute();
$stmt->close();

$stmt = $conn->prepare('UPDATE users SET is_verified = 1 WHERE id = ?');
$stmt->bind_param('i', $userId);
$stmt->execute();
$stmt->close();

$conn->close();

respond(true, 'Email verified. You can now sign in.');