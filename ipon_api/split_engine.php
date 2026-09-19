<?php
require_once __DIR__ . '/config.php';

/**
 * Computes each member's share of a plan target.
 *
 * @param float $target  the plan's target amount
 * @param array $members list of [
 *                         'user_id'      => int,
 *                         'weight'       => float,
 *                         'is_locked'    => bool,
 *                         'share_amount' => float  (used when locked)
 *                       ]
 *
 * @return array{
 *   ok: bool,
 *   error: string|null,
 *   members: array,
 *   locked_total: float,
 *   computed_total: float,
 *   assigned_total: float,
 *   unallocated: float
 * }
 */
function compute_split(float $target, array $members): array
{
    $failure = static function (string $message) use ($members): array {
        return [
            'ok'             => false,
            'error'          => $message,
            'members'        => $members,
            'locked_total'   => 0.0,
            'computed_total' => 0.0,
            'assigned_total' => 0.0,
            'unallocated'    => 0.0,
        ];
    };

    if ($target <= 0) {
        return $failure('The plan target must be greater than zero.');
    }

    if (count($members) === 0) {
        return $failure('This plan has no members to split between.');
    }
    $locked = [];
    $unlocked = [];
    $lockedTotal = 0.0;

    foreach ($members as $member) {
        $weight = isset($member['weight']) ? (float) $member['weight'] : 1.0;
        $isLocked = !empty($member['is_locked']);
        $amount = isset($member['share_amount']) ? (float) $member['share_amount'] : 0.0;

        if ($weight < 0) {
            return $failure('Weights cannot be negative.');
        }

        if ($isLocked) {
            if ($amount < 0) {
                return $failure('A fixed amount cannot be negative.');
            }
            $lockedTotal += $amount;
            $locked[] = ['user_id' => (int) $member['user_id'], 'amount' => round($amount, 2)];
        } else {
            $unlocked[] = ['user_id' => (int) $member['user_id'], 'weight' => $weight];
        }
    }

    $lockedTotal = round($lockedTotal, 2);

    if ($lockedTotal - $target > 0.005) {
        $over = round($lockedTotal - $target, 2);
        return $failure(
            'The fixed amounts add up to more than the plan target by '
            . number_format($over, 2) . '. Lower one of them or raise the target.'
        );
    }

    $remaining = round($target - $lockedTotal, 2);
    if (count($unlocked) === 0) {
        $result = [];
        foreach ($locked as $entry) {
            $result[$entry['user_id']] = $entry['amount'];
        }

        return [
            'ok'             => true,
            'error'          => null,
            'members'        => _merge_amounts($members, $result),
            'locked_total'   => $lockedTotal,
            'computed_total' => 0.0,
            'assigned_total' => $lockedTotal,
            'unallocated'    => round($target - $lockedTotal, 2),
        ];
    }
    $totalWeight = 0.0;
    foreach ($unlocked as $entry) {
        $totalWeight += $entry['weight'];
    }
    if ($totalWeight <= 0) {
        foreach ($unlocked as $index => $entry) {
            $unlocked[$index]['weight'] = 1.0;
        }
        $totalWeight = (float) count($unlocked);
    }

    $amounts = [];
    $runningTotal = 0.0;
    $lastIndex = count($unlocked) - 1;

    foreach ($unlocked as $index => $entry) {
        if ($index === $lastIndex) {
            $amount = round($remaining - $runningTotal, 2);
        } else {
            $amount = round($remaining * ($entry['weight'] / $totalWeight), 2);
            $runningTotal += $amount;
        }

        $amounts[$entry['user_id']] = $amount;
    }

    foreach ($locked as $entry) {
        $amounts[$entry['user_id']] = $entry['amount'];
    }

    $computedTotal = round($remaining, 2);

    return [
        'ok'             => true,
        'error'          => null,
        'members'        => _merge_amounts($members, $amounts),
        'locked_total'   => $lockedTotal,
        'computed_total' => $computedTotal,
        'assigned_total' => round($lockedTotal + $computedTotal, 2),
        'unallocated'    => 0.0,
    ];
}

function _merge_amounts(array $members, array $amountsByUserId): array
{
    $out = [];

    foreach ($members as $member) {
        $userId = (int) $member['user_id'];
        $member['user_id'] = $userId;
        $member['weight'] = isset($member['weight']) ? (float) $member['weight'] : 1.0;
        $member['is_locked'] = !empty($member['is_locked']);
        $member['share_amount'] = isset($amountsByUserId[$userId])
            ? round((float) $amountsByUserId[$userId], 2)
            : 0.0;
        $out[] = $member;
    }

    return $out;
}

function ensure_contribution_rows(mysqli $conn, int $planId, int $groupId): void
{
    $sql = 'INSERT IGNORE INTO plan_contributions (plan_id, user_id, weight, is_locked)
            SELECT ?, gm.user_id, 1.000, 0
              FROM group_members gm
             WHERE gm.group_id = ?';

    $stmt = $conn->prepare($sql);
    $stmt->bind_param('ii', $planId, $groupId);
    $stmt->execute();
    $stmt->close();
    $cleanup = 'DELETE pc FROM plan_contributions pc
                 WHERE pc.plan_id = ?
                   AND pc.user_id NOT IN (
                       SELECT gm.user_id FROM group_members gm WHERE gm.group_id = ?
                   )';
    $stmt = $conn->prepare($cleanup);
    $stmt->bind_param('ii', $planId, $groupId);
    $stmt->execute();
    $stmt->close();
}

function load_contributions(mysqli $conn, int $planId): array
{
    $sql = 'SELECT pc.user_id, pc.weight, pc.is_locked, pc.share_amount,
                   pc.paid_amount, u.full_name, u.email
              FROM plan_contributions pc
              JOIN users u ON u.id = pc.user_id
             WHERE pc.plan_id = ?
             ORDER BY u.full_name ASC';

    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $planId);
    $stmt->execute();
    $result = $stmt->get_result();

    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = [
            'user_id'      => (int) $row['user_id'],
            'full_name'    => $row['full_name'],
            'email'        => $row['email'],
            'weight'       => (float) $row['weight'],
            'is_locked'    => ((int) $row['is_locked'] === 1),
            'share_amount' => round((float) $row['share_amount'], 2),
            'paid_amount'  => round((float) $row['paid_amount'], 2),
        ];
    }
    $stmt->close();

    return $rows;
}

function decorate_with_payments(array $members): array
{
    $out = [];

    foreach ($members as $member) {
        $share = (float) ($member['share_amount'] ?? 0);
        $paid = (float) ($member['paid_amount'] ?? 0);

        $member['remaining']   = round($share - $paid, 2);
        $member['is_settled']  = (($share - $paid) <= 0.005);
        $member['paid_percent'] = $share > 0
            ? round(min($paid / $share, 1.0) * 100, 1)
            : 0.0;

        $out[] = $member;
    }

    return $out;
}