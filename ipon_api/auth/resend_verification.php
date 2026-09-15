<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../mailer.php';

$body = read_json_body();
$email = isset($body['email']) ? strtolower(trim((string) $body['email'])) : '';

if ($email === '') {
    respond(false, 'Email is required.', null, 400);
}

$conn = get_db();

$stmt = $conn->prepare('SELECT id, full_name, is_verified FROM users WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    respond(false, 'No account found with that email address.', null, 404);
}

if ((int) $user['is_verified'] === 1) {
    respond(true, 'This account is already verified. You can sign in.');
}

$userId = (int) $user['id'];
$fullName = (string) $user['full_name'];

$stmt = $conn->prepare(
    'UPDATE email_verifications
        SET consumed_at = NOW()
      WHERE user_id = ? AND consumed_at IS NULL'
);
$stmt->bind_param('i', $userId);
$stmt->execute();
$stmt->close();

$code = generate_code();
$expiresAt = date('Y-m-d H:i:s', strtotime('+30 minutes'));

$stmt = $conn->prepare(
    'INSERT INTO email_verifications (user_id, code, expires_at) VALUES (?, ?, ?)'
);
$stmt->bind_param('iss', $userId, $code, $expiresAt);
$stmt->execute();
$stmt->close();

$conn->close();

send_app_mail(
    $email,
    $fullName,
    'Your new Ipon verification code',
    build_code_email(
        'Here is your new code',
        'Use this code to verify your email address:',
        $code,
        'This code expires in 30 minutes and replaces any earlier code.'
    )
);

respond(true, 'A new verification code has been sent to your email.');