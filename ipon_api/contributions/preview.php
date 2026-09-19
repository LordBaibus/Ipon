<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../split_engine.php';
require_once __DIR__ . '/../plans/detail.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);

$planId = isset($body['plan_id']) ? (int) $body['plan_id'] : 0;
if ($planId <= 0) {
    respond(false, 'Plan is required.', null, 400);
}

$plan = require_plan_access($conn, $planId, $user['id']);

if ($plan['group_id'] === null) {
    respond(false, 'Personal plans are not split between members.', null, 400);
}

ensure_contribution_rows($conn, $planId, (int) $plan['group_id']);
$existing = load_contributions($conn, $planId);
$conn->close();

$target = round((float) $plan['target_amount'], 2);
$byUserId = [];
foreach ($existing as $row) {
    $byUserId[$row['user_id']] = $row;
}

$proposed = isset($body['members']) && is_array($body['members'])
    ? $body['members']
    : [];

foreach ($proposed as $change) {
    if (!is_array($change) || !isset($change['user_id'])) {
        continue;
    }

    $userId = (int) $change['user_id'];
    if (!isset($byUserId[$userId])) {
        continue;
    }

    if (array_key_exists('weight', $change)) {
        $byUserId[$userId]['weight'] = (float) $change['weight'];
    }

    if (array_key_exists('is_locked', $change)) {
        $byUserId[$userId]['is_locked'] = (bool) $change['is_locked'];
    }

    if (array_key_exists('share_amount', $change)) {
        $byUserId[$userId]['share_amount'] = (float) $change['share_amount'];
    }
}

$members = array_values($byUserId);
$result = compute_split($target, $members);

if (!$result['ok']) {
    respond(false, (string) $result['error'], ['target_amount' => $target], 400);
}

respond(true, '', [
    'plan_id'        => $planId,
    'target_amount'  => $target,
    'members'        => decorate_with_payments($result['members']),
    'locked_total'   => $result['locked_total'],
    'assigned_total' => $result['assigned_total'],
    'unallocated'    => $result['unallocated'],
]);