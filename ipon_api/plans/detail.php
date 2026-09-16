<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';

function require_plan_access(mysqli $conn, int $planId, int $userId): array
{
    $stmt = $conn->prepare(
        'SELECT id, owner_id, group_id, name, plan_type, target_amount,
                deadline, notes, created_at
           FROM plans
          WHERE id = ?
          LIMIT 1'
    );
    $stmt->bind_param('i', $planId);
    $stmt->execute();
    $plan = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$plan) {
        respond(false, 'Plan not found.', null, 404);
    }

    $plan['id'] = (int) $plan['id'];
    $plan['owner_id'] = (int) $plan['owner_id'];
    $plan['group_id'] = $plan['group_id'] === null ? null : (int) $plan['group_id'];

    if ($plan['group_id'] === null) {
        if ($plan['owner_id'] !== $userId) {
            respond(false, 'You do not have access to this plan.', null, 403);
        }
    } else {
        require_group_member($conn, $plan['group_id'], $userId);
    }

    return $plan;
}

function load_plan_categories(mysqli $conn, int $planId): array
{
    $stmt = $conn->prepare(
        'SELECT id, label, amount, sort_order
           FROM plan_categories
          WHERE plan_id = ?
          ORDER BY sort_order ASC, id ASC'
    );
    $stmt->bind_param('i', $planId);
    $stmt->execute();
    $result = $stmt->get_result();

    $categories = [];
    while ($row = $result->fetch_assoc()) {
        $categories[] = [
            'id'         => (int) $row['id'],
            'label'      => $row['label'],
            'amount'     => round((float) $row['amount'], 2),
            'sort_order' => (int) $row['sort_order'],
        ];
    }
    $stmt->close();

    return $categories;
}

if (basename((string) ($_SERVER['SCRIPT_FILENAME'] ?? '')) === 'detail.php') {
    $body = read_json_body();
    $conn = get_db();
    $user = require_user($conn, $body);

    $planId = isset($body['plan_id']) ? (int) $body['plan_id'] : 0;
    if ($planId <= 0) {
        respond(false, 'Plan is required.', null, 400);
    }

    $plan = require_plan_access($conn, $planId, $user['id']);
    $categories = load_plan_categories($conn, $planId);

    $groupName = null;
    if ($plan['group_id'] !== null) {
        $stmt = $conn->prepare('SELECT name FROM expense_groups WHERE id = ? LIMIT 1');
        $stmt->bind_param('i', $plan['group_id']);
        $stmt->execute();
        $groupRow = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        $groupName = $groupRow ? $groupRow['name'] : null;
    }

    $conn->close();

    $target = round((float) $plan['target_amount'], 2);
    $allocated = 0.0;
    foreach ($categories as $category) {
        $allocated += $category['amount'];
    }
    $allocated = round($allocated, 2);

    respond(true, '', [
        'id'              => $plan['id'],
        'name'            => $plan['name'],
        'plan_type'       => $plan['plan_type'],
        'target_amount'   => $target,
        'allocated_total' => $allocated,
        'unallocated'     => round($target - $allocated, 2),
        'group_id'        => $plan['group_id'],
        'group_name'      => $groupName,
        'is_personal'     => $plan['group_id'] === null,
        'is_owner'        => ($plan['owner_id'] === $user['id']),
        'deadline'        => $plan['deadline'],
        'notes'           => $plan['notes'],
        'created_at'      => $plan['created_at'],
        'categories'      => $categories,
    ]);
}