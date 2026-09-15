<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../mailer.php';

$body = read_json_body();
$email = isset($body['email']) ? strtolower(trim((string) $body['email'])) : '';

if ($email === '') {
    respond(false, 'Email is required.', null, 400);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond(false, 'Please enter a valid email address.', null, 400);
}

$genericMessage = 'If that email is registered, a reset code has been sent to it.';

$conn = get_db();

$stmt = $conn->prepare('SELECT id, full_name FROM users WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    $conn->close();
    respond(true, $genericMessage);
}

$userId = (int) $user['id'];
$fullName = (string) $user['full_name'];

$stmt = $conn->prepare(
    'UPDATE password_resets
        SET consumed_at = NOW()
      WHERE user_id = ? AND consumed_at IS NULL'
);
$stmt->bind_param('i', $userId);
$stmt->execute();
$stmt->close();

$code = generate_code();
$expiresAt = date('Y-m-d H:i:s', strtotime('+30 minutes'));

$stmt = $conn->prepare(
    'INSERT INTO password_resets (user_id, code, expires_at) VALUES (?, ?, ?)'
);
$stmt->bind_param('iss', $userId, $code, $expiresAt);
$stmt->execute();
$stmt->close();

$conn->close();

send_app_mail(
    $email,
    $fullName,
    'Reset your Ipon password',
    build_code_email(
        'Password reset requested',
        'Use this code to set a new password:',
        $code,
        'This code expires in 30 minutes. If you did not request a password reset, you can safely ignore this email.'
    )
);

respond(true, $genericMessage);