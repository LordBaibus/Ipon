<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../expense_helper.php';

$body = read_json_body();
$conn = get_db();
$user = require_user($conn, $body);
$userId = $user['id'];
$where = [];
$types = '';
$params = [];

$scope = isset($body['scope']) ? trim((string) $body['scope']) : 'all';
$groupFilter = isset($body['group_id']) && $body['group_id'] !== null && $body['group_id'] !== ''
    ? (int) $body['group_id']
    : 0;

if ($groupFilter > 0) {
    require_group_member($conn, $groupFilter, $userId);
    $where[] = 'e.group_id = ?';
    $types .= 'i';
    $params[] = $groupFilter;
} elseif ($scope === 'personal') {
    $where[] = '(e.user_id = ? AND e.group_id IS NULL)';
    $types .= 'i';
    $params[] = $userId;
} elseif ($scope === 'group') {
    $where[] = 'e.group_id IN (SELECT gm.group_id FROM group_members gm WHERE gm.user_id = ?)';
    $types .= 'i';
    $params[] = $userId;
} else {
    $where[] = '((e.user_id = ? AND e.group_id IS NULL)
                 OR e.group_id IN (SELECT gm.group_id FROM group_members gm WHERE gm.user_id = ?))';
    $types .= 'ii';
    $params[] = $userId;
    $params[] = $userId;
}

foreach (['date_from' => '>=', 'date_to' => '<='] as $key => $operator) {
    if (!isset($body[$key]) || trim((string) $body[$key]) === '') continue;

    $value = trim((string) $body[$key]);
    $parsed = DateTime::createFromFormat('Y-m-d', $value);
    if (!$parsed || $parsed->format('Y-m-d') !== $value) {
        respond(false, 'Dates must be in YYYY-MM-DD format.', null, 400);
    }

    $where[] = "e.expense_date $operator ?";
    $types .= 's';
    $params[] = $value;
}

$whereSql = 'WHERE ' . implode(' AND ', $where);
$runScoped = static function (mysqli $conn, string $sql, string $types, array $params) {
    $stmt = $conn->prepare($sql);
    if ($types !== '') {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $rows;
};
$totals = $runScoped(
    $conn,
    "SELECT COUNT(*) AS c,
            COALESCE(SUM(e.amount), 0) AS total,
            COALESCE(SUM(CASE WHEN e.source = 'ocr' THEN 1 ELSE 0 END), 0) AS ocr_count
       FROM expenses e
       $whereSql",
    $types,
    $params
)[0];

$totalSpent = round((float) $totals['total'], 2);
$categoryRows = $runScoped(
    $conn,
    "SELECT COALESCE(pc.label, e.category) AS label,
            COALESCE(SUM(e.amount), 0)     AS total,
            COUNT(*)                       AS c
       FROM expenses e
  LEFT JOIN plan_categories pc ON pc.id = e.plan_category_id
       $whereSql
   GROUP BY label
   ORDER BY total DESC",
    $types,
    $params
);

$byCategory = [];
foreach ($categoryRows as $row) {
    $amount = round((float) $row['total'], 2);
    $byCategory[] = [
        'label'         => $row['label'],
        'total'         => $amount,
        'count'         => (int) $row['c'],
        'share_percent' => $totalSpent > 0
            ? round(($amount / $totalSpent) * 100, 1)
            : 0.0,
    ];
}
$monthRows = $runScoped(
    $conn,
    "SELECT DATE_FORMAT(e.expense_date, '%Y-%m') AS month,
            COALESCE(SUM(e.amount), 0)           AS total
       FROM expenses e
       $whereSql
   GROUP BY month
   ORDER BY month ASC",
    $types,
    $params
);

$byMonth = [];
foreach ($monthRows as $row) {
    $byMonth[] = [
        'month' => $row['month'],
        'total' => round((float) $row['total'], 2),
    ];
}
$planSql = 'SELECT p.id,
                   p.name,
                   p.target_amount,
                   p.group_id,
                   g.name AS group_name,
                   (SELECT COALESCE(SUM(c.amount), 0)
                      FROM plan_categories c WHERE c.plan_id = p.id) AS allocated,
                   (SELECT COALESCE(SUM(x.amount), 0)
                      FROM expenses x WHERE x.plan_id = p.id)        AS spent
              FROM plans p
         LEFT JOIN expense_groups g ON g.id = p.group_id
             WHERE (p.owner_id = ? AND p.group_id IS NULL)
                OR p.group_id IN (SELECT gm.group_id FROM group_members gm WHERE gm.user_id = ?)
          ORDER BY p.created_at DESC';

$stmt = $conn->prepare($planSql);
$stmt->bind_param('ii', $userId, $userId);
$stmt->execute();
$planRows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
$stmt->close();

$planProgress = [];
foreach ($planRows as $row) {
    $target = round((float) $row['target_amount'], 2);
    $spent = round((float) $row['spent'], 2);

    $planProgress[] = [
        'plan_id'        => (int) $row['id'],
        'name'           => $row['name'],
        'group_name'     => $row['group_name'],
        'is_personal'    => $row['group_id'] === null,
        'target_amount'  => $target,
        'allocated'      => round((float) $row['allocated'], 2),
        'spent'          => $spent,
        'remaining'      => round($target - $spent, 2),
        'spent_percent'  => $target > 0 ? round(($spent / $target) * 100, 1) : 0.0,
        'is_overspent'   => ($spent - $target) > 0.005,
    ];
}
$recentRows = $runScoped(
    $conn,
    "SELECT e.*,
            u.full_name  AS payer_name,
            g.name       AS group_name,
            p.name       AS plan_name,
            pc.label     AS category_label
       FROM expenses e
       JOIN users u            ON u.id  = e.user_id
  LEFT JOIN expense_groups g    ON g.id  = e.group_id
  LEFT JOIN plans p             ON p.id  = e.plan_id
  LEFT JOIN plan_categories pc  ON pc.id = e.plan_category_id
       $whereSql
   ORDER BY e.expense_date DESC, e.id DESC
      LIMIT 5",
    $types,
    $params
);

$recent = [];
foreach ($recentRows as $row) {
    $recent[] = format_expense_row($row, $userId);
}

$conn->close();

respond(true, '', [
    'total_spent'    => $totalSpent,
    'expense_count'  => (int) $totals['c'],
    'ocr_count'      => (int) $totals['ocr_count'],
    'by_category'    => $byCategory,
    'by_month'       => $byMonth,
    'plan_progress'  => $planProgress,
    'recent'         => $recent,
]);