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
    respond(false, 'Personal plans do not track member payments.', null, 400);
}

$targetUserId = isset($body['user_id']) ? (int) $body['user_id'] : $user['id'];
$isSelf = ($targetUserId === $user['id']);
$isPlanOwner = ($plan['owner_id'] === $user['id']);

if (!$isSelf && !$isPlanOwner) {
    respond(
        false,
        'Only the person who created this plan can record a payment for someone else.',
        null,
        403
    );
}

if (!isset($body['amount'])) {
    respond(false, 'Amount is required.', null, 400);
}

$amount = round((float) $body['amount'], 2);

if ($amount < 0) {
    respond(false, 'Amount cannot be negative.', null, 400);
}

if ($amount > 99999999.99) {
    respond(false, 'Amount is too large.', null, 400);
}

$mode = isset($body['mode']) ? strtolower(trim((string) $body['mode'])) : 'set';
if ($mode !== 'set' && $mode !== 'add') {
    respond(false, "Mode must be either 'set' or 'add'.", null, 400);
}
$stmt = $conn->prepare(
    'SELECT paid_amount, share_amount
       FROM plan_contributions
      WHERE plan_id = ? AND user_id = ?
      LIMIT 1'
);
$stmt->bind_param('ii', $planId, $targetUserId);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$row) {
    respond(false, 'That person is not part of this plan.', null, 404);
}

$currentPaid = round((float) $row['paid_amount'], 2);
$newPaid = ($mode === 'add') ? round($currentPaid + $amount, 2) : $amount;

if ($newPaid < 0) {
    respond(false, 'That would make the recorded payment negative.', null, 400);
}

$stmt = $conn->prepare(
    'UPDATE plan_contributions SET paid_amount = ? WHERE plan_id = ? AND user_id = ?'
);
$stmt->bind_param('dii', $newPaid, $planId, $targetUserId);

if (!$stmt->execute()) {
    $stmt->close();
    $conn->close();
    respond(false, 'Could not record the payment. Please try again.', null, 500);
}
$stmt->close();
$saved = load_contributions($conn, $planId);
$conn->close();

$target = round((float) $plan['target_amount'], 2);
$paidTotal = 0.0;
$assignedTotal = 0.0;
foreach ($saved as $entry) {
    $paidTotal += $entry['paid_amount'];
    $assignedTotal += $entry['share_amount'];
}

$share = round((float) $row['share_amount'], 2);
$message = ($newPaid >= $share && $share > 0)
    ? 'Payment recorded. This share is fully settled.'
    : 'Payment recorded.';

respond(true, $message, [
    'plan_id'        => $planId,
    'user_id'        => $targetUserId,
    'paid_amount'    => $newPaid,
    'share_amount'   => $share,
    'remaining'      => round($share - $newPaid, 2),
    'target_amount'  => $target,
    'members'        => decorate_with_payments($saved),
    'assigned_total' => round($assignedTotal, 2),
    'paid_total'     => round($paidTotal, 2),
]);