<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/detail.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);
$userId = $user['id'];

$planId = isset($body['plan_id']) ? (int) $body['plan_id'] : 0;
if ($planId <= 0) {
    respond(false, 'Plan is required.', null, 400);
}

$plan = require_plan_access($conn, $planId, $userId);

if ($plan['owner_id'] !== $userId) {
    respond(false, 'Only the person who created this plan can delete it.', null, 403);
}

$stmt = $conn->prepare('DELETE FROM plans WHERE id = ?');
$stmt->bind_param('i', $planId);

if (!$stmt->execute()) {
    $stmt->close();
    $conn->close();
    respond(false, 'Could not delete the plan. Please try again.', null, 500);
}

$stmt->close();
$conn->close();

respond(true, 'Plan deleted.');