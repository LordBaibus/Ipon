<?php
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/auth_helper.php';
require_once __DIR__ . '/helpers.php';

function validate_expense_fields(array $body, array $defaults = []): array
{
    $amount = array_key_exists('amount', $body)
        ? (float) $body['amount']
        : (float) ($defaults['amount'] ?? 0);

    if ($amount <= 0) {
        respond(false, 'Amount must be greater than zero.', null, 400);
    }

    if ($amount > 99999999.99) {
        respond(false, 'Amount is too large.', null, 400);
    }
    $merchant = array_key_exists('merchant', $body)
        ? trim((string) $body['merchant'])
        : (string) ($defaults['merchant'] ?? '');

    if (text_length($merchant) > 120) {
        respond(false, 'Merchant name is too long (120 characters max).', null, 400);
    }
    $category = array_key_exists('category', $body)
        ? trim((string) $body['category'])
        : (string) ($defaults['category'] ?? '');

    if ($category === '') {
        $category = 'Uncategorized';
    }

    if (text_length($category) > 60) {
        respond(false, 'Category is too long (60 characters max).', null, 400);
    }
    $rawDate = array_key_exists('expense_date', $body)
        ? trim((string) $body['expense_date'])
        : (string) ($defaults['expense_date'] ?? '');

    if ($rawDate === '') {
        $rawDate = date('Y-m-d');
    }

    $parsed = DateTime::createFromFormat('Y-m-d', $rawDate);
    if (!$parsed || $parsed->format('Y-m-d') !== $rawDate) {
        respond(false, 'Date must be a valid date in YYYY-MM-DD format.', null, 400);
    }
    if (strtotime($rawDate) > strtotime('+1 year')) {
        respond(false, 'That date is too far in the future.', null, 400);
    }
    $notes = array_key_exists('notes', $body)
        ? trim((string) $body['notes'])
        : (string) ($defaults['notes'] ?? '');

    if (text_length($notes) > 255) {
        respond(false, 'Notes are too long (255 characters max).', null, 400);
    }
    $source = array_key_exists('source', $body)
        ? strtolower(trim((string) $body['source']))
        : (string) ($defaults['source'] ?? 'manual');

    if ($source !== 'manual' && $source !== 'ocr') {
        $source = 'manual';
    }

    return [
        'amount'       => round($amount, 2),
        'merchant'     => ($merchant === '') ? null : $merchant,
        'category'     => $category,
        'expense_date' => $rawDate,
        'notes'        => ($notes === '') ? null : $notes,
        'source'       => $source,
    ];
}

function resolve_expense_links(mysqli $conn, array $body, int $userId): array
{
    $groupId = null;
    $planId = null;
    $categoryId = null;
    if (isset($body['group_id']) && $body['group_id'] !== null && $body['group_id'] !== '') {
        $groupId = (int) $body['group_id'];
        if ($groupId <= 0) {
            respond(false, 'Invalid group.', null, 400);
        }
        require_group_member($conn, $groupId, $userId);
    }
    if (isset($body['plan_id']) && $body['plan_id'] !== null && $body['plan_id'] !== '') {
        $planId = (int) $body['plan_id'];
        if ($planId <= 0) {
            respond(false, 'Invalid plan.', null, 400);
        }

        require_once __DIR__ . '/plans/detail.php';
        $plan = require_plan_access($conn, $planId, $userId);

        if ($plan['group_id'] !== null) {
            if ($groupId !== null && $groupId !== (int) $plan['group_id']) {
                respond(
                    false,
                    'That plan belongs to a different group.',
                    null,
                    400
                );
            }
            $groupId = (int) $plan['group_id'];
        }
    }
    if (isset($body['plan_category_id'])
        && $body['plan_category_id'] !== null
        && $body['plan_category_id'] !== ''
    ) {
        $categoryId = (int) $body['plan_category_id'];
        if ($categoryId <= 0) {
            respond(false, 'Invalid budget category.', null, 400);
        }

        if ($planId === null) {
            respond(
                false,
                'Choose a plan before choosing one of its budget categories.',
                null,
                400
            );
        }

        $stmt = $conn->prepare(
            'SELECT id FROM plan_categories WHERE id = ? AND plan_id = ? LIMIT 1'
        );
        $stmt->bind_param('ii', $categoryId, $planId);
        $stmt->execute();
        $found = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$found) {
            respond(
                false,
                'That budget category does not belong to the selected plan.',
                null,
                400
            );
        }
    }

    return [
        'group_id'         => $groupId,
        'plan_id'          => $planId,
        'plan_category_id' => $categoryId,
    ];
}

function require_expense_access(mysqli $conn, int $expenseId, int $userId): array
{
    $stmt = $conn->prepare(
        'SELECT id, user_id, group_id, plan_id, plan_category_id, merchant,
                amount, category, expense_date, notes, source, created_at
           FROM expenses
          WHERE id = ?
          LIMIT 1'
    );
    $stmt->bind_param('i', $expenseId);
    $stmt->execute();
    $expense = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$expense) {
        respond(false, 'Expense not found.', null, 404);
    }

    $expense['id'] = (int) $expense['id'];
    $expense['user_id'] = (int) $expense['user_id'];
    $expense['group_id'] = $expense['group_id'] === null
        ? null
        : (int) $expense['group_id'];
    $expense['plan_id'] = $expense['plan_id'] === null
        ? null
        : (int) $expense['plan_id'];
    $expense['plan_category_id'] = $expense['plan_category_id'] === null
        ? null
        : (int) $expense['plan_category_id'];

    if ($expense['group_id'] === null) {
        if ($expense['user_id'] !== $userId) {
            respond(false, 'You do not have access to this expense.', null, 403);
        }
    } else {
        require_group_member($conn, $expense['group_id'], $userId);
    }

    return $expense;
}
function format_expense_row(array $row, int $currentUserId): array
{
    return [
        'id'               => (int) $row['id'],
        'user_id'          => (int) $row['user_id'],
        'payer_name'       => $row['payer_name'] ?? null,
        'is_mine'          => ((int) $row['user_id'] === $currentUserId),
        'group_id'         => $row['group_id'] === null ? null : (int) $row['group_id'],
        'group_name'       => $row['group_name'] ?? null,
        'plan_id'          => $row['plan_id'] === null ? null : (int) $row['plan_id'],
        'plan_name'        => $row['plan_name'] ?? null,
        'plan_category_id' => $row['plan_category_id'] === null
            ? null
            : (int) $row['plan_category_id'],
        'category_label'   => $row['category_label'] ?? null,
        'merchant'         => $row['merchant'],
        'amount'           => round((float) $row['amount'], 2),
        'category'         => $row['category'],
        'expense_date'     => $row['expense_date'],
        'notes'            => $row['notes'],
        'source'           => $row['source'],
        'is_personal'      => ($row['group_id'] === null),
        'created_at'       => $row['created_at'] ?? null,
    ];
}