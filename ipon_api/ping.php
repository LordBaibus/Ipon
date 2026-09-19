<?php
require_once __DIR__ . '/config.php';
$conn = get_db();
$conn->close();

respond(true, 'Server is reachable.', [
    'server_time' => date('c'),
]);