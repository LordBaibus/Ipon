<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../plan_templates.php';

$body = read_json_body();
$conn = get_db();
require_user($conn, $body);
$conn->close();

$target = isset($body['target_amount']) ? (float) $body['target_amount'] : 0.0;

$out = [];
foreach (plan_templates() as $key => $template) {
    $row = [
        'key'         => $key,
        'label'       => $template['label'],
        'description' => $template['description'],
        'categories'  => $template['categories'],
    ];

    if ($target > 0) {
        $row['preview'] = allocate_amounts($target, $template['categories']);
    }

    $out[] = $row;
}

respond(true, '', $out);