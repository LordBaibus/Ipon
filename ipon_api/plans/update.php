<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../helpers.php';
require_once __DIR__ . '/../plan_templates.php';
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
$name = isset($body['name']) ? trim((string) $body['name']) : (string) $plan['name'];
$targetAmount = isset($body['target_amount'])
    ? (float) $body['target_amount']
    : (float) $plan['target_amount'];

if ($name === '') {
    respond(false, 'Plan name is required.', null, 400);
}

if (text_length($name) > 120) {
    respond(false, 'Plan name is too long (120 characters max).', null, 400);
}

if ($targetAmount <= 0) {
    respond(false, 'Target amount must be greater than zero.', null, 400);
}

if ($targetAmount > 99999999.99) {
    respond(false, 'Target amount is too large.', null, 400);
}

$deadlineValue = $plan['deadline'];
if (array_key_exists('deadline', $body)) {
    $deadline = trim((string) $body['deadline']);

    if ($deadline === '') {
        $deadlineValue = null;
    } else {
        $parsed = DateTime::createFromFormat('Y-m-d', $deadline);
        if (!$parsed || $parsed->format('Y-m-d') !== $deadline) {
            respond(false, 'Deadline must be a valid date in YYYY-MM-DD format.', null, 400);
        }
        $deadlineValue = $deadline;
    }
}

$notesValue = $plan['notes'];
if (array_key_exists('notes', $body)) {
    $notes = trim((string) $body['notes']);

    if (text_length($notes) > 255) {
        respond(false, 'Notes are too long (255 characters max).', null, 400);
    }
    $notesValue = ($notes === '') ? null : $notes;
}

$newCategories = null;   // null means "leave categories untouched"

if (isset($body['categories']) && is_array($body['categories'])) {
    if (count($body['categories']) > 20) {
        respond(false, 'A plan can have at most 20 categories.', null, 400);
    }

    $newCategories = [];
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

        $newCategories[] = ['label' => $label, 'amount' => $amount];
    }
} elseif (isset($body['reapply_template']) && $body['reapply_template']) {
    $newCategories = [];
    foreach (suggest_categories((string) $plan['plan_type'], $targetAmount) as $suggested) {
        $newCategories[] = [
            'label'  => $suggested['label'],
            'amount' => $suggested['amount'],
        ];
    }
}

$conn->begin_transaction();

try {
    $stmt = $conn->prepare(
        'UPDATE plans
            SET name = ?, target_amount = ?, deadline = ?, notes = ?
          WHERE id = ?'
    );
    $stmt->bind_param('sdssi', $name, $targetAmount, $deadlineValue, $notesValue, $planId);
    $stmt->execute();
    $stmt->close();

    if ($newCategories !== null) {
        $stmt = $conn->prepare('DELETE FROM plan_categories WHERE plan_id = ?');
        $stmt->bind_param('i', $planId);
        $stmt->execute();
        $stmt->close();

        if (count($newCategories) > 0) {
            $stmt = $conn->prepare(
                'INSERT INTO plan_categories (plan_id, label, amount, sort_order)
                 VALUES (?, ?, ?, ?)'
            );
            foreach ($newCategories as $index => $category) {
                $label = $category['label'];
                $amount = $category['amount'];
                $stmt->bind_param('isdi', $planId, $label, $amount, $index);
                $stmt->execute();
            }
            $stmt->close();
        }
    }

    $conn->commit();
} catch (\Throwable $e) {
    $conn->rollback();
    $conn->close();
    respond(false, 'Could not update the plan. Please try again.', null, 500);
}

$categories = load_plan_categories($conn, $planId);
$conn->close();

$allocated = 0.0;
foreach ($categories as $category) {
    $allocated += $category['amount'];
}
$allocated = round($allocated, 2);
$target = round($targetAmount, 2);

respond(true, 'Plan updated.', [
    'id'              => $planId,
    'name'            => $name,
    'plan_type'       => $plan['plan_type'],
    'target_amount'   => $target,
    'allocated_total' => $allocated,
    'unallocated'     => round($target - $allocated, 2),
    'group_id'        => $plan['group_id'],
    'deadline'        => $deadlineValue,
    'notes'           => $notesValue,
    'categories'      => $categories,
]);