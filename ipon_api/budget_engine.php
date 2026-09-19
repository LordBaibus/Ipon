<?php
require_once __DIR__ . '/config.php';

function compute_budget_cycle(int $cycleStartDay, string $referenceDate): array
{
    $cycleStartDay = max(1, min(31, $cycleStartDay));

    $ref = new DateTime($referenceDate);
    $refDay = (int) $ref->format('j');
    $refYear = (int) $ref->format('Y');
    $refMonth = (int) $ref->format('n');
    $daysInRefMonth = (int) $ref->format('t');
    $anchorDayThisMonth = min($cycleStartDay, $daysInRefMonth);

    if ($refDay >= $anchorDayThisMonth) {
        $startYear = $refYear;
        $startMonth = $refMonth;
    } else {
        $startMonth = $refMonth - 1;
        $startYear = $refYear;
        if ($startMonth < 1) {
            $startMonth = 12;
            $startYear--;
        }
    }

    $daysInStartMonth = (int) (new DateTime(
        sprintf('%04d-%02d-01', $startYear, $startMonth)
    ))->format('t');
    $startDay = min($cycleStartDay, $daysInStartMonth);

    $start = new DateTime(sprintf('%04d-%02d-%02d', $startYear, $startMonth, $startDay));
    $nextMonth = $startMonth + 1;
    $nextYear = $startYear;
    if ($nextMonth > 12) {
        $nextMonth = 1;
        $nextYear++;
    }
    $daysInNextMonth = (int) (new DateTime(
        sprintf('%04d-%02d-01', $nextYear, $nextMonth)
    ))->format('t');
    $nextStartDay = min($cycleStartDay, $daysInNextMonth);

    $nextStart = new DateTime(sprintf('%04d-%02d-%02d', $nextYear, $nextMonth, $nextStartDay));
    $end = (clone $nextStart)->modify('-1 day');

    $lengthDays = (int) $start->diff($end)->days + 1;

    return [
        'start'       => $start->format('Y-m-d'),
        'end'         => $end->format('Y-m-d'),
        'length_days' => $lengthDays,
    ];
}

function compute_budget_pacing(
    float $limitAmount,
    array $cycle,
    array $expensesInCycle,
    string $referenceDate
): array {
    $lengthDays = max(1, $cycle['length_days']);
    $dailyPace = $limitAmount / $lengthDays;
    $today = new DateTime($referenceDate);
    $cycleStart = new DateTime($cycle['start']);
    $cycleEnd = new DateTime($cycle['end']);
    $clampedToday = $today;
    if ($today < $cycleStart) {
        $clampedToday = clone $cycleStart;
    } elseif ($today > $cycleEnd) {
        $clampedToday = clone $cycleEnd;
    }
    $daysElapsed = (int) $cycleStart->diff($clampedToday)->days + 1;

    $windows = [
        'today'         => 1,
        'last_7_days'   => 7,
        'last_15_days'  => 15,
        'cycle_to_date' => $daysElapsed,
    ];

    $sums = [];
    foreach (array_keys($windows) as $key) {
        $sums[$key] = 0.0;
    }
    $cycleTotal = 0.0;

    foreach ($expensesInCycle as $row) {
        $amount = (float) $row['amount'];
        $date = new DateTime((string) $row['expense_date']);
        $cycleTotal += $amount;

        foreach ($windows as $key => $windowDays) {
            $windowStart = (clone $clampedToday)->modify('-' . ($windowDays - 1) . ' days');
            if ($windowStart < $cycleStart) {
                $windowStart = clone $cycleStart;
            }
            if ($date >= $windowStart && $date <= $clampedToday) {
                $sums[$key] += $amount;
            }
        }
    }

    $breakdown = [];
    foreach ($windows as $key => $windowDays) {
        $effectiveDays = min($windowDays, $daysElapsed);
        $expected = $dailyPace * $effectiveDays;
        $actual = round($sums[$key], 2);
        $diff = $actual - $expected;
        $percentVsPace = $expected > 0
            ? round(($diff / $expected) * 100, 1)
            : ($actual > 0 ? 100.0 : 0.0);

        $breakdown[$key] = [
            'actual'          => $actual,
            'expected'        => round($expected, 2),
            'percent_vs_pace' => $percentVsPace,
            'status'          => $diff > 0 ? 'over' : ($diff < 0 ? 'under' : 'on_pace'),
        ];
    }

    $remaining = round($limitAmount - $cycleTotal, 2);
    $daysRemaining = max(0, $lengthDays - $daysElapsed);
    $observedDailyRate = $daysElapsed > 0 ? ($cycleTotal / $daysElapsed) : 0.0;
    $projectedTotal = round($cycleTotal + ($observedDailyRate * $daysRemaining), 2);

    return [
        'limit_amount'    => round($limitAmount, 2),
        'daily_pace'      => round($dailyPace, 2),
        'cycle_start'     => $cycle['start'],
        'cycle_end'       => $cycle['end'],
        'cycle_length'    => $lengthDays,
        'days_elapsed'    => $daysElapsed,
        'days_remaining'  => $daysRemaining,
        'spent_total'     => round($cycleTotal, 2),
        'remaining'       => $remaining,
        'is_over_limit'   => $remaining < 0,
        'projected_total' => $projectedTotal,
        'projected_over'  => round($projectedTotal - $limitAmount, 2),
        'breakdown'       => $breakdown,
    ];
}