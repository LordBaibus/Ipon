<?php

require_once __DIR__ . '/config.php';

define('MAIL_ENABLED', false);
define('SMTP_HOST',    'smtp.hostinger.com');
define('SMTP_PORT',    465);
define('SMTP_USER',    'noreply@yourdomain.com');
define('SMTP_PASS',    'your-email-password');
define('SMTP_FROM',    'noreply@yourdomain.com');
define('SMTP_FROM_NAME', 'Ipon');
// ---------------------------------------------

function send_app_mail(string $toEmail, string $toName, string $subject, string $htmlBody): bool
{
    if (!MAIL_ENABLED) {
        return log_mail_locally($toEmail, $subject, $htmlBody);
    }

    $phpmailerPath = __DIR__ . '/lib/PHPMailer/src/';
    if (!file_exists($phpmailerPath . 'PHPMailer.php')) {
        error_log('Ipon: PHPMailer not installed, falling back to local log.');
        return log_mail_locally($toEmail, $subject, $htmlBody);
    }

    require_once $phpmailerPath . 'Exception.php';
    require_once $phpmailerPath . 'PHPMailer.php';
    require_once $phpmailerPath . 'SMTP.php';

    $mail = new \PHPMailer\PHPMailer\PHPMailer(true);

    try {
        $mail->isSMTP();
        $mail->Host       = SMTP_HOST;
        $mail->SMTPAuth   = true;
        $mail->Username   = SMTP_USER;
        $mail->Password   = SMTP_PASS;
        $mail->SMTPSecure = (SMTP_PORT === 465) ? 'ssl' : 'tls';
        $mail->Port       = SMTP_PORT;
        $mail->CharSet    = 'UTF-8';

        $mail->setFrom(SMTP_FROM, SMTP_FROM_NAME);
        $mail->addAddress($toEmail, $toName);

        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body    = $htmlBody;
        $mail->AltBody = strip_tags(str_replace(['<br>', '</p>'], "\n", $htmlBody));

        $mail->send();
        return true;
    } catch (\Throwable $e) {
        error_log('Ipon mail error: ' . $e->getMessage());
        return false;
    }
}

function log_mail_locally(string $toEmail, string $subject, string $htmlBody): bool
{
    $line = str_repeat('=', 60) . "\n"
        . 'TIME:    ' . date('Y-m-d H:i:s') . "\n"
        . 'TO:      ' . $toEmail . "\n"
        . 'SUBJECT: ' . $subject . "\n"
        . strip_tags(str_replace(['<br>', '</p>'], "\n", $htmlBody)) . "\n";

    @file_put_contents(__DIR__ . '/mail_debug.log', $line, FILE_APPEND);
    return true;
}

function build_code_email(string $heading, string $intro, string $code, string $note): string
{
    return '<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto">'
        . '<h2 style="color:#1f6feb">' . htmlspecialchars($heading) . '</h2>'
        . '<p>' . htmlspecialchars($intro) . '</p>'
        . '<p style="font-size:30px;font-weight:bold;letter-spacing:6px;'
        . 'background:#f2f4f8;padding:14px;text-align:center;border-radius:8px">'
        . htmlspecialchars($code) . '</p>'
        . '<p style="color:#666;font-size:13px">' . htmlspecialchars($note) . '</p>'
        . '<p style="color:#999;font-size:12px">— The Ipon Team</p>'
        . '</div>';
}

function generate_code(): string
{
    return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
}