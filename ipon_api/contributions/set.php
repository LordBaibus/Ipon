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

if (count($existing) === 0) {
    respond(false, 'This plan has no members to split between.', null, 400);
}

$target = round((float) $plan['target_amount'], 2);

$byUserId = [];
foreach ($existing as $row) {
    $byUserId[$row['user_id']] = $row;
}

$requested = isset($body['members']) && is_array($body['members'])
    ? $body['members']
    : [];

foreach ($requested as $change) {
    if (!is_array($change) || !isset($change['user_id'])) {
        continue;
    }

    $userId = (int) $change['user_id'];

    if (!isset($byUserId[$userId])) {
        continue;
    }

    if (array_key_exists('weight', $change)) {
        $weight = (float) $change['weight'];
        if ($weight < 0) {
            respond(false, 'Weights cannot be negative.', null, 400);
        }
        if ($weight > 1000) {
            respond(false, 'Weights must be 1000 or less.', null, 400);
        }
        $byUserId[$userId]['weight'] = $weight;
    }

    if (array_key_exists('is_locked', $change)) {
        $byUserId[$userId]['is_locked'] = (bool) $change['is_locked'];
    }

    if (array_key_exists('share_amount', $change)) {
        $amount = (float) $change['share_amount'];
        if ($amount < 0) {
            respond(false, 'A fixed amount cannot be negative.', null, 400);
        }
        $byUserId[$userId]['share_amount'] = round($amount, 2);
    }
}

$result = compute_split($target, array_values($byUserId));

if (!$result['ok']) {
    // Nothing has been written yet, so a failed validation leaves the
    // saved split exactly as it was.
    respond(false, (string) $result['error'], ['target_amount' => $target], 400);
}

$conn->begin_transaction();

try {
    $stmt = $conn->prepare(
        'UPDATE plan_contributions
            SET weight = ?, is_locked = ?, share_amount = ?
          WHERE plan_id = ? AND user_id = ?'
    );

    foreach ($result['members'] as $member) {
        $weight = (float) $member['weight'];
        $isLocked = !empty($member['is_locked']) ? 1 : 0;
        $share = (float) $member['share_amount'];
        $memberId = (int) $member['user_id'];

        $stmt->bind_param('didii', $weight, $isLocked, $share, $planId, $memberId);
        $stmt->execute();
    }

    $stmt->close();
    $conn->commit();
} catch (\Throwable $e) {
    $conn->rollback();
    $conn->close();
    respond(false, 'Could not save the split. Please try again.', null, 500);
}
$saved = load_contributions($conn, $planId);
$conn->close();

$paidTotal = 0.0;
$assignedTotal = 0.0;
$lockedTotal = 0.0;
foreach ($saved as $row) {
    $paidTotal += $row['paid_amount'];
    $assignedTotal += $row['share_amount'];
    if ($row['is_locked']) {
        $lockedTotal += $row['share_amount'];
    }
}

respond(true, 'Split saved.', [
    'plan_id'        => $planId,
    'target_amount'  => $target,
    'members'        => decorate_with_payments($saved),
    'locked_total'   => round($lockedTotal, 2),
    'assigned_total' => round($assignedTotal, 2),
    'unallocated'    => round($target - $assignedTotal, 2),
    'paid_total'     => round($paidTotal, 2),
]);