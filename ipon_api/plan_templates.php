<?php

require_once __DIR__ . '/config.php';

function plan_templates(): array
{
    return [
        'trip' => [
            'label' => 'Trip / Getaway',
            'description' => 'Out-of-town travel with lodging and transport.',
            'categories' => [
                ['label' => 'Lodging',        'percent' => 30.0],
                ['label' => 'Transportation', 'percent' => 25.0],
                ['label' => 'Food',           'percent' => 25.0],
                ['label' => 'Activities',     'percent' => 10.0],
                ['label' => 'Buffer',         'percent' => 10.0],
            ],
        ],
        'event' => [
            'label' => 'Event / Celebration',
            'description' => 'Birthdays, reunions, despedidas, parties.',
            'categories' => [
                ['label' => 'Venue',          'percent' => 30.0],
                ['label' => 'Food & Drinks',  'percent' => 35.0],
                ['label' => 'Decorations',    'percent' => 15.0],
                ['label' => 'Program & Misc', 'percent' => 10.0],
                ['label' => 'Buffer',         'percent' => 10.0],
            ],
        ],
        'project' => [
            'label' => 'Project',
            'description' => 'School or work project with materials and services.',
            'categories' => [
                ['label' => 'Materials',    'percent' => 40.0],
                ['label' => 'Equipment',    'percent' => 20.0],
                ['label' => 'Services',     'percent' => 20.0],
                ['label' => 'Printing',     'percent' => 10.0],
                ['label' => 'Buffer',       'percent' => 10.0],
            ],
        ],
        'savings_goal' => [
            'label' => 'Savings Goal',
            'description' => 'Saving toward one purchase, such as a laptop or phone.',
            'categories' => [
                ['label' => 'Main Purchase', 'percent' => 85.0],
                ['label' => 'Accessories',   'percent' => 10.0],
                ['label' => 'Buffer',        'percent' => 5.0],
            ],
        ],
        'custom' => [
            'label' => 'Custom',
            'description' => 'Start from scratch and add your own categories.',
            'categories' => [],
        ],
    ];
}

function is_valid_plan_type(string $type): bool
{
    return array_key_exists($type, plan_templates());
}

function allocate_amounts(float $target, array $categories): array
{
    if (count($categories) === 0) {
        return [];
    }

    $allocated = [];
    $runningTotal = 0.0;
    $lastIndex = count($categories) - 1;

    foreach ($categories as $index => $category) {
        $percent = (float) $category['percent'];

        if ($index === $lastIndex) {
            // Exact remainder — absorbs all rounding drift.
            $amount = round($target - $runningTotal, 2);
        } else {
            $amount = round($target * $percent / 100.0, 2);
            $runningTotal += $amount;
        }

        $allocated[] = [
            'label'   => (string) $category['label'],
            'amount'  => $amount,
            'percent' => $percent,
        ];
    }

    return $allocated;
}

function suggest_categories(string $planType, float $target): array
{
    $templates = plan_templates();

    if (!isset($templates[$planType])) {
        return [];
    }

    return allocate_amounts($target, $templates[$planType]['categories']);
}