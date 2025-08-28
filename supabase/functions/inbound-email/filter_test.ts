#!/usr/bin/env -S deno run --allow-all
// Simple integration test for task filtering functionality

import { filterTasksForDedup } from './index.ts';

function assert(condition: boolean, message: string) {
  if (!condition) {
    console.error(`❌ ${message}`);
    Deno.exit(1);
  }
  console.log(`✅ ${message}`);
}

console.log('🧪 Testing filterTasksForDedup function...\n');

const now = new Date('2025-01-01T12:00:00Z');

// Test 1: Basic filtering
const tasks1 = [
  { id: 1, title: "Past task", due_date: '2024-12-31T23:59:59Z' },
  { id: 2, title: "Current task", due_date: '2025-01-01T12:00:00Z' },
  { id: 3, title: "Future task", due_date: '2025-01-02T00:00:00Z' },
  { id: 4, title: "No due date", due_date: null },
  { id: 5, title: "Undefined due date" }
];

const filtered1 = filterTasksForDedup(tasks1, now);
const ids1 = filtered1.map(t => t.id);
assert(ids1.length === 4, 'Should filter out 1 past task');
assert(ids1.includes(2), 'Should keep current task (boundary case)');
assert(ids1.includes(3), 'Should keep future task');
assert(ids1.includes(4), 'Should keep null due_date task');
assert(ids1.includes(5), 'Should keep undefined due_date task');
assert(!ids1.includes(1), 'Should filter out past task');

// Test 2: Edge cases
const tasks2 = [
  { id: 1, due_date: 'invalid-date' },
  { id: 2, due_date: '' },
  { id: 3, due_date: undefined },
  { id: 4, due_date: null }
];

const filtered2 = filterTasksForDedup(tasks2, now);
assert(filtered2.length === 4, 'Should keep all tasks with invalid/empty dates (fail open)');

// Test 3: Empty array
const filtered3 = filterTasksForDedup([], now);
assert(filtered3.length === 0, 'Should handle empty array');

// Test 4: All future tasks
const tasks4 = [
  { id: 1, due_date: '2025-01-02T00:00:00Z' },
  { id: 2, due_date: '2025-01-03T00:00:00Z' }
];

const filtered4 = filterTasksForDedup(tasks4, now);
assert(filtered4.length === 2, 'Should keep all future tasks');

// Test 5: All past tasks
const tasks5 = [
  { id: 1, due_date: '2024-12-30T00:00:00Z' },
  { id: 2, due_date: '2024-12-31T23:59:59Z' }
];

const filtered5 = filterTasksForDedup(tasks5, now);
assert(filtered5.length === 0, 'Should filter out all past tasks');

console.log('\n🎉 All tests passed! Task filtering is working correctly.');
console.log('\n📝 Summary:');
console.log('   - Past tasks (due_date < now) are filtered out');
console.log('   - Current and future tasks (due_date >= now) are kept');
console.log('   - Tasks with no due_date or invalid dates are kept (fail-open)');
console.log('   - This ensures only relevant tasks are sent to AI for deduplication');
