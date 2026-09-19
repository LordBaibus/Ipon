<?php
require_once __DIR__ . '/config.php';
function compute_group_balances(array $members, array $paidByUserId, float $totalSpent): array
{
    $count = count($members);
    if ($count === 0) return [];
    $baseShare = round($totalSpent / $count, 2);

    $rows = [];
    $runningOwed = 0.0;

    foreach ($members as $index => $member) {
        $owed = ($index === $count - 1)
            ? round($totalSpent - $runningOwed, 2)
            : $baseShare;

        if ($index !== $count - 1) {
            $runningOwed += $owed;
        }

        $userId = (int) $member['user_id'];
        $paid = round((float) ($paidByUserId[$userId] ?? 0), 2);

        $rows[] = [
            'user_id'   => $userId,
            'full_name' => $member['full_name'],
            'paid'      => $paid,
            'owed'      => $owed,
            'net'       => round($paid - $owed, 2),
        ];
    }

    return $rows;
}

function settle_balances(array $balances): array
{
    $debtors = [];   // owe money (negative net)
    $creditors = []; // are owed money (positive net)

    foreach ($balances as $row) {
        $net = round((float) $row['net'], 2);

        if ($net < -0.005) {
            $debtors[] = [
                'user_id' => $row['user_id'],
                'name'    => $row['full_name'],
                'amount'  => -$net,
            ];
        } elseif ($net > 0.005) {
            $creditors[] = [
                'user_id' => $row['user_id'],
                'name'    => $row['full_name'],
                'amount'  => $net,
            ];
        }
    }
    usort($debtors, static fn($a, $b) => $b['amount'] <=> $a['amount']);
    usort($creditors, static fn($a, $b) => $b['amount'] <=> $a['amount']);

    $transfers = [];
    $i = 0;
    $j = 0;
    $guard = 0;
    $maxIterations = count($debtors) + count($creditors) + 1;

    while ($i < count($debtors) && $j < count($creditors) && $guard <= $maxIterations) {
        $guard++;

        $amount = round(min($debtors[$i]['amount'], $creditors[$j]['amount']), 2);

        if ($amount > 0.005) {
            $transfers[] = [
                'from_user_id' => $debtors[$i]['user_id'],
                'from_name'    => $debtors[$i]['name'],
                'to_user_id'   => $creditors[$j]['user_id'],
                'to_name'      => $creditors[$j]['name'],
                'amount'       => $amount,
            ];
        }

        $debtors[$i]['amount'] = round($debtors[$i]['amount'] - $amount, 2);
        $creditors[$j]['amount'] = round($creditors[$j]['amount'] - $amount, 2);

        if ($debtors[$i]['amount'] <= 0.005) $i++;
        if ($creditors[$j]['amount'] <= 0.005) $j++;
    }

    return $transfers;
}