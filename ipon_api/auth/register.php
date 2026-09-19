<?php
date_default_timezone_set('Asia/Manila');
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../helpers.php';
require_once __DIR__ . '/../mailer.php';

$body = read_json_body();

$fullName = isset($body['full_name']) ? trim((string) $body['full_name']) : '';
$email    = isset($body['email']) ? strtolower(trim((string) $body['email'])) : '';
$password = isset($body['password']) ? (string) $body['password'] : '';

if ($fullName === '' || $email === '' || $password === '') {
    respond(false, 'Full name, email, and password are all required.', null, 400);
}

if (text_length($fullName) > 100) {
    respond(false, 'Full name is too long.', null, 400);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond(false, 'Please enter a valid email address.', null, 400);
}

if (strlen($password) < 8) {
    respond(false, 'Password must be at least 8 characters long.', null, 400);
}

$conn = get_db();

$stmt = $conn->prepare('SELECT id FROM users WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$existing = $stmt->get_result()->fetch_assoc();
$stmt->close();

if ($existing) {
    respond(false, 'An account with that email already exists.', null, 409);
}

$passwordHash = password_hash($password, PASSWORD_DEFAULT);

$stmt = $conn->prepare(
    'INSERT INTO users (full_name, email, password_hash, is_verified)
     VALUES (?, ?, ?, 0)'
);
$stmt->bind_param('sss', $fullName, $email, $passwordHash);

if (!$stmt->execute()) {
    $stmt->close();
    $conn->close();
    respond(false, 'Could not create the account. Please try again.', null, 500);
}

$userId = (int) $conn->insert_id;
$stmt->close();

$code = generate_code();
$expiresAt = date('Y-m-d H:i:s', strtotime('+30 minutes'));

$stmt = $conn->prepare(
    'INSERT INTO email_verifications (user_id, code, expires_at)
     VALUES (?, ?, ?)'
);
$stmt->bind_param('iss', $userId, $code, $expiresAt);
$stmt->execute();
$stmt->close();

$conn->close();

send_app_mail(
    $email,
    $fullName,
    'Verify your Ipon account',
    build_code_email(
        'Welcome to Ipon',
        'Use this code to verify your email address:',
        $code,
        'This code expires in 30 minutes. If you did not create an Ipon account, you can ignore this email.'
    )
);

respond(
    true,
    'Account created. Check your email for the verification code.',
    ['email' => $email],
    201
);