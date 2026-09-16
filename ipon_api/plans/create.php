<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../helpers.php';
require_once __DIR__ . '/../plan_templates.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);
$userId = $user['id'];

$name = isset($body['name']) ? trim((string) $body['name']) : '';
$planType = isset($body['plan_type']) ? trim((string) $body['plan_type']) : 'custom';
$targetAmount = isset($body['target_amount']) ? (float) $body['target_amount'] : 0.0;
$notes = isset($body['notes']) ? trim((string) $body['notes']) : '';
$deadline = isset($body['deadline']) ? trim((string) $body['deadline']) : '';

if ($name === '') {
    respond(false, 'Plan name is required.', null, 400);
}

if (text_length($name) > 120) {
    respond(false, 'Plan name is too long (120 characters max).', null, 400);
}

if (!is_valid_plan_type($planType)) {
    respond(false, 'Unknown plan type.', null, 400);
}

if ($targetAmount <= 0) {
    respond(false, 'Target amount must be greater than zero.', null, 400);
}

if ($targetAmount > 99999999.99) {
    respond(false, 'Target amount is too large.', null, 400);
}

if (text_length($notes) > 255) {
    respond(false, 'Notes are too long (255 characters max).', null, 400);
}

$deadlineValue = null;
if ($deadline !== '') {
    $parsed = DateTime::createFromFormat('Y-m-d', $deadline);
    $isRealDate = $parsed && $parsed->format('Y-m-d') === $deadline;

    if (!$isRealDate) {
        respond(false, 'Deadline must be a valid date in YYYY-MM-DD format.', null, 400);
    }
    $deadlineValue = $deadline;
}

$groupId = null;
if (isset($body['group_id']) && $body['group_id'] !== null && $body['group_id'] !== '') {
    $groupId = (int) $body['group_id'];

    if ($groupId <= 0) {
        respond(false, 'Invalid group.', null, 400);
    }

    // Ends the request with 403 if this user is not in that group.
    require_group_member($conn, $groupId, $userId);
}

$categories = [];

if (isset($body['categories']) && is_array($body['categories']) && count($body['categories']) > 0) {
    if (count($body['categories']) > 20) {
        respond(false, 'A plan can have at most 20 categories.', null, 400);
    }

    foreach ($body['categories'] as $raw) {
        if (!is_array($raw)) {
            respond(false, 'Each category must include a label and an amount.', null, 400);
        }

        $label = isset($raw['label']) ? trim((string) $raw['label']) : '';
        $amount = isset($raw['amount']) ? round((float) $raw['amount'], 2) : 0.0;

        if ($label === '') {
            respond(false, 'Every category needs a label.', null, 400);
        }

        if (text_length($label) > 80) {
            respond(false, 'Category label is too long (80 characters max).', null, 400);
        }

        if ($amount < 0) {
            respond(false, 'Category amounts cannot be negative.', null, 400);
        }

        $categories[] = ['label' => $label, 'amount' => $amount];
    }
} else {
    foreach (suggest_categories($planType, $targetAmount) as $suggested) {
        $categories[] = [
            'label'  => $suggested['label'],
            'amount' => $suggested['amount'],
        ];
    }
}

$conn->begin_transaction();

try {
    $stmt = $conn->prepare(
        'INSERT INTO plans
            (owner_id, group_id, name, plan_type, target_amount, deadline, notes)
         VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $notesValue = ($notes === '') ? null : $notes;
    $stmt->bind_param(
        'iissdss',
        $userId,
        $groupId,
        $name,
        $planType,
        $targetAmount,
        $deadlineValue,
        $notesValue
    );
    $stmt->execute();
    $planId = (int) $conn->insert_id;
    $stmt->close();

    if (count($categories) > 0) {
        $stmt = $conn->prepare(
            'INSERT INTO plan_categories (plan_id, label, amount, sort_order)
             VALUES (?, ?, ?, ?)'
        );

        foreach ($categories as $index => $category) {
            $label = $category['label'];
            $amount = $category['amount'];
            $stmt->bind_param('isdi', $planId, $label, $amount, $index);
            $stmt->execute();
        }
        $stmt->close();
    }

    $conn->commit();
} catch (\Throwable $e) {
    $conn->rollback();
    $conn->close();
    respond(false, 'Could not create the plan. Please try again.', null, 500);
}

$conn->close();

$allocated = 0.0;
$categoryOut = [];
foreach ($categories as $index => $category) {
    $allocated += $category['amount'];
    $categoryOut[] = [
        'label'      => $category['label'],
        'amount'     => $category['amount'],
        'sort_order' => $index,
    ];
}

respond(true, 'Plan created.', [
    'id'               => $planId,
    'name'             => $name,
    'plan_type'        => $planType,
    'target_amount'    => round($targetAmount, 2),
    'group_id'         => $groupId,
    'deadline'         => $deadlineValue,
    'notes'            => $notesValue,
    'categories'       => $categoryOut,
    'allocated_total'  => round($allocated, 2),
    'unallocated'      => round($targetAmount - $allocated, 2),
], 201);