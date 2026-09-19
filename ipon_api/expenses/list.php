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

if (isset($body['plan_id']) && $body['plan_id'] !== null && $body['plan_id'] !== '') {
    $where[] = 'e.plan_id = ?';
    $types .= 'i';
    $params[] = (int) $body['plan_id'];
}

if (isset($body['plan_category_id'])
    && $body['plan_category_id'] !== null
    && $body['plan_category_id'] !== ''
) {
    $where[] = 'e.plan_category_id = ?';
    $types .= 'i';
    $params[] = (int) $body['plan_category_id'];
}

if (isset($body['category']) && trim((string) $body['category']) !== '') {
    $where[] = 'e.category = ?';
    $types .= 's';
    $params[] = trim((string) $body['category']);
}

if (isset($body['source'])) {
    $source = strtolower(trim((string) $body['source']));
    if ($source === 'manual' || $source === 'ocr') {
        $where[] = 'e.source = ?';
        $types .= 's';
        $params[] = $source;
    }
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

if (isset($body['search']) && trim((string) $body['search']) !== '') {
    $needle = '%' . trim((string) $body['search']) . '%';
    $where[] = '(e.merchant LIKE ? OR e.notes LIKE ? OR e.category LIKE ?)';
    $types .= 'sss';
    $params[] = $needle;
    $params[] = $needle;
    $params[] = $needle;
}

$whereSql = 'WHERE ' . implode(' AND ', $where);
$totalsSql = "SELECT COUNT(*) AS c, COALESCE(SUM(e.amount), 0) AS total
                FROM expenses e
                $whereSql";

$stmt = $conn->prepare($totalsSql);
if ($types !== '') {
    $stmt->bind_param($types, ...$params);
}
$stmt->execute();
$totals = $stmt->get_result()->fetch_assoc();
$stmt->close();
$limit = isset($body['limit']) ? (int) $body['limit'] : 100;
if ($limit <= 0) $limit = 100;
if ($limit > 500) $limit = 500;

$offset = isset($body['offset']) ? (int) $body['offset'] : 0;
if ($offset < 0) $offset = 0;

$sql = "SELECT e.*,
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
         LIMIT ? OFFSET ?";

$pageTypes = $types . 'ii';
$pageParams = $params;
$pageParams[] = $limit;
$pageParams[] = $offset;

$stmt = $conn->prepare($sql);
$stmt->bind_param($pageTypes, ...$pageParams);
$stmt->execute();
$result = $stmt->get_result();

$expenses = [];
while ($row = $result->fetch_assoc()) {
    $expenses[] = format_expense_row($row, $userId);
}
$stmt->close();
$conn->close();

respond(true, '', [
    'expenses'     => $expenses,
    'total_count'  => (int) $totals['c'],
    'total_amount' => round((float) $totals['total'], 2),
    'limit'        => $limit,
    'offset'       => $offset,
]);