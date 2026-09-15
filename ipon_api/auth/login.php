<?php

require_once __DIR__ . '/../config.php';

$body = read_json_body();

$email    = isset($body['email']) ? strtolower(trim((string) $body['email'])) : '';
$password = isset($body['password']) ? (string) $body['password'] : '';

if ($email === '' || $password === '') {
    respond(false, 'Email and password are required.', null, 400);
}

$conn = get_db();

$stmt = $conn->prepare(
    'SELECT id, full_name, email, password_hash, is_verified
       FROM users
      WHERE email = ?
      LIMIT 1'
);
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user || !password_verify($password, $user['password_hash'])) {
    respond(false, 'Incorrect email or password.', null, 401);
}

if ((int) $user['is_verified'] !== 1) {
    respond(
        false,
        'Please verify your email address before signing in.',
        ['needs_verification' => true, 'email' => $user['email']],
        403
    );
}

$userId = (int) $user['id'];
$token = bin2hex(random_bytes(32));
$expiresAt = date('Y-m-d H:i:s', strtotime('+30 days'));

$stmt = $conn->prepare(
    'UPDATE users SET session_token = ?, session_expires_at = ? WHERE id = ?'
);
$stmt->bind_param('ssi', $token, $expiresAt, $userId);
$stmt->execute();
$stmt->close();

$conn->close();

respond(true, 'Signed in successfully.', [
    'token' => $token,
    'user'  => [
        'id'        => $userId,
        'full_name' => $user['full_name'],
        'email'     => $user['email'],
    ],
]);