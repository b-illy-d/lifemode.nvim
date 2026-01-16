-- Test script for T20: Minimal query views for tasks
-- Usage: nvim -l test_t20.lua

-- Add lifemode to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Load lifemode
local lifemode = require('lifemode')

-- Setup with test vault
lifemode.setup({
  vault_root = vim.fn.getcwd(),
  leader = '<Space>',
})

print("=== T20: Task Query Views Test ===\n")

-- Create test files with various tasks
print("Creating test files with tasks...")

local today = os.date("%Y-%m-%d")
local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)

local file1_content = {
  "# Project Alpha",
  "",
  "- [ ] Task due today !1 #alpha @due(" .. today .. ") ^task-today-1",
  "- [ ] Task due tomorrow #alpha @due(" .. tomorrow .. ") ^task-tomorrow-1",
  "- [ ] Overdue task #alpha @due(" .. yesterday .. ") ^task-overdue-1",
  "- [x] Completed task #alpha @due(" .. today .. ") ^task-done-1",
  "- [ ] Task no due date #alpha ^task-no-due-1",
}

local file2_content = {
  "# Project Beta",
  "",
  "- [ ] Another task today !2 #beta #urgent @due(" .. today .. ") ^task-today-2",
  "- [ ] Beta task no tags @due(" .. tomorrow .. ") ^task-beta-notag",
  "- [ ] Urgent task #urgent @due(" .. today .. ") ^task-urgent-1",
}

vim.fn.writefile(file1_content, 'test_project_alpha.md')
vim.fn.writefile(file2_content, 'test_project_beta.md')

print("✓ Test files created")

-- Build vault index
print("\nBuilding vault index...")
local index = require('lifemode.index')
local vault_index = index.build_vault_index(vim.fn.getcwd())

local config = lifemode.get_config()
config.vault_index = vault_index

local node_count = 0
for _ in pairs(vault_index.node_locations) do
  node_count = node_count + 1
end

print("✓ Index built: " .. node_count .. " nodes")

-- Debug: Show what's in the index
print("\nDebug: Index contents:")
local debug_count = 0
for node_id, location in pairs(vault_index.node_locations) do
  debug_count = debug_count + 1
  if debug_count <= 5 then
    print("  " .. node_id .. " at " .. location.file .. ":" .. location.line)
  end
end

-- Test 1: Get all tasks
print("\n=== Test 1: Get All Tasks ===")
local query = require('lifemode.query')
local all_tasks = query.get_all_tasks()

-- Debug: Show task extraction
if #all_tasks == 0 then
  print("\nDebug: Checking first file manually...")
  local file = io.open('test_project_alpha.md', 'r')
  if file then
    local line_num = 0
    for line in file:lines() do
      line_num = line_num + 1
      print("  Line " .. line_num .. ": " .. line)
      if line:match("^%s*%-.--%s*%[.%]") then
        print("    -> Matches task pattern!")
      end
    end
    file:close()
  end
end

print("Total tasks found: " .. #all_tasks)

if #all_tasks < 8 then
  print("✗ FAIL: Expected at least 8 tasks, found " .. #all_tasks)
  os.exit(1)
end

print("✓ All tasks retrieved")

-- Test 2: Filter by state
print("\n=== Test 2: Filter by State ===")
local todo_tasks = query.filter_tasks(all_tasks, { state = "todo" })
local done_tasks = query.filter_tasks(all_tasks, { state = "done" })

print("TODO tasks: " .. #todo_tasks)
print("DONE tasks: " .. #done_tasks)

if #todo_tasks < 7 then
  print("✗ FAIL: Expected 7+ TODO tasks, found " .. #todo_tasks)
  os.exit(1)
end

if #done_tasks < 1 then
  print("✗ FAIL: Expected 1+ DONE tasks, found " .. #done_tasks)
  os.exit(1)
end

print("✓ State filtering works")

-- Test 3: Filter by tag
print("\n=== Test 3: Filter by Tag ===")
local alpha_tasks = query.filter_tasks(all_tasks, { tag = "alpha" })
local beta_tasks = query.filter_tasks(all_tasks, { tag = "beta" })
local urgent_tasks = query.filter_tasks(all_tasks, { tag = "urgent" })

print("#alpha tasks: " .. #alpha_tasks)
print("#beta tasks: " .. #beta_tasks)
print("#urgent tasks: " .. #urgent_tasks)

if #alpha_tasks < 4 then
  print("✗ FAIL: Expected 4+ alpha tasks, found " .. #alpha_tasks)
  os.exit(1)
end

if #beta_tasks < 1 then
  print("✗ FAIL: Expected 1+ beta tasks, found " .. #beta_tasks)
  os.exit(1)
end

if #urgent_tasks < 1 then
  print("✗ FAIL: Expected 1+ urgent tasks, found " .. #urgent_tasks)
  os.exit(1)
end

print("✓ Tag filtering works")

-- Test 4: Filter by due date (today)
print("\n=== Test 4: Filter by Due Date (Today) ===")
local tasks_today = query.get_tasks_today()

print("Tasks due today (TODO only): " .. #tasks_today)

if #tasks_today < 2 then
  print("✗ FAIL: Expected 2+ tasks due today, found " .. #tasks_today)
  os.exit(1)
end

-- Verify all are TODO
for _, task in ipairs(tasks_today) do
  if task.state ~= "todo" then
    print("✗ FAIL: Found non-TODO task in today's tasks")
    os.exit(1)
  end
  if task.due ~= today then
    print("✗ FAIL: Found task with wrong due date: " .. (task.due or "nil"))
    os.exit(1)
  end
end

print("✓ Due date filtering (today) works")

-- Test 5: Filter by due date (overdue)
print("\n=== Test 5: Filter by Due Date (Overdue) ===")
local overdue_tasks = query.get_overdue_tasks()

print("Overdue tasks: " .. #overdue_tasks)

if #overdue_tasks < 1 then
  print("✗ FAIL: Expected 1+ overdue tasks, found " .. #overdue_tasks)
  os.exit(1)
end

print("✓ Overdue filtering works")

-- Test 6: Get tasks by tag
print("\n=== Test 6: Get Tasks by Tag ===")
local alpha_todo = query.get_tasks_by_tag("alpha")

print("TODO tasks with #alpha: " .. #alpha_todo)

if #alpha_todo < 3 then
  print("✗ FAIL: Expected 3+ alpha TODO tasks, found " .. #alpha_todo)
  os.exit(1)
end

-- Verify all are TODO and have alpha tag
for _, task in ipairs(alpha_todo) do
  if task.state ~= "todo" then
    print("✗ FAIL: Found non-TODO task in filtered results")
    os.exit(1)
  end
  local has_alpha = false
  for _, tag in ipairs(task.tags) do
    if tag == "alpha" or tag:match("^alpha") then
      has_alpha = true
      break
    end
  end
  if not has_alpha then
    print("✗ FAIL: Task without alpha tag in results")
    os.exit(1)
  end
end

print("✓ get_tasks_by_tag works")

-- Test 7: Quickfix conversion
print("\n=== Test 7: Quickfix Conversion ===")
local qf_list = query.tasks_to_quickfix(tasks_today)

print("Quickfix entries: " .. #qf_list)

if #qf_list ~= #tasks_today then
  print("✗ FAIL: Quickfix entry count doesn't match task count")
  os.exit(1)
end

-- Verify quickfix format
for _, entry in ipairs(qf_list) do
  if not entry.filename or not entry.lnum or not entry.text then
    print("✗ FAIL: Invalid quickfix entry format")
    os.exit(1)
  end
end

print("✓ Quickfix conversion works")

-- Test 8: Command execution (simulated)
print("\n=== Test 8: Command Simulation ===")

-- We can't directly test vim commands in headless mode easily,
-- but we can verify the functions they call work
local tasks_all = query.get_all_todo_tasks()
print("All TODO tasks: " .. #tasks_all)

if #tasks_all < 7 then
  print("✗ FAIL: get_all_todo_tasks returned too few results")
  os.exit(1)
end

print("✓ Command functions work")

print("\n=== All T20 Tests Passed ===")
print("\nManual verification:")
print("1. Open a vault with tasks")
print("2. Run :LifeModeTasksToday - see tasks due today in quickfix")
print("3. Run :LifeModeTasksByTag alpha - see tasks tagged #alpha")
print("4. Run :LifeModeTasksAll - see all TODO tasks")
print("5. Run :LifeModeTasksOverdue - see overdue tasks")
print("6. Press <Space>vt in markdown file - interactive tag picker")
print("7. Press <Space>vv - see all tasks")
