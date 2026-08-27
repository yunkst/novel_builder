---
name: flutter-bugfix
description: This skill should be used when debugging Flutter/Dart applications that display unexpected UI behavior, especially issues related to state management, widget lifecycle, and reactive updates. Use this skill when encountering bugs where the UI doesn't update correctly despite data being loaded, blank screens, stale data, or widgets not responding to state changes. The skill specializes in Riverpod state management issues, widget rebuild problems, and Flutter reactive programming patterns.
---

# Flutter BugFix Skill

## Purpose

Debug and fix Flutter/Dart application bugs related to state management, widget lifecycle, and reactive UI updates. This skill specializes in diagnosing issues where the UI doesn't reflect the actual application state, particularly in Riverpod-based applications.

## When to Use This Skill

Use this skill when encountering:
- Blank screens or empty content despite successful data loading
- UI not updating after state changes
- Stale data displayed in widgets
- Widgets not rebuilding when they should
- Riverpod provider state not triggering UI updates
- Confusion about `ref.watch()` vs `ref.read()` usage
- Async data loading not reflected in UI

## Debugging Workflow

### Phase 1: Understand the Bug Symptoms

1. **Gather Bug Description**
   - Ask: "What are you seeing vs. what do you expect to see?"
   - Ask: "Is the data actually loaded (check logs/network)?"
   - Ask: "Does the bug happen consistently or intermittently?"
   - Ask: "What actions trigger the bug?"

2. **Initial Assessment**
   - Determine if this is a state management issue, widget lifecycle issue, or data loading issue
   - Check if the user has confirmed data is actually loaded (not empty)
   - **Key indicator**: User stating "data is not empty, but screen shows blank" = state management problem

### Phase 2: Locate Relevant Code

1. **Find the Widget Displaying the Issue**
   - Use `Glob` to find screen/widget files: `**/*_screen.dart`
   - Use `Grep` to search for specific widget class names

2. **Find State Management Code**
   - Locate Provider definitions: `**/*_providers.dart`
   - Find Controller classes: `**/controllers/*.dart`
   - Check for State/Notifier classes: `**/*_notifier.dart`, `**/*_state.dart`

3. **Identify Data Flow**
   - Trace from data source (API/repository) → Provider → Controller → Widget
   - Look for `ref.watch()`, `ref.read()`, and state getters

### Phase 3: Create Unit Tests to Reproduce

1. **Create Test File**
   - Create: `test/**/*_bug_test.dart` or `test/**/*_issue_test.dart`
   - Use descriptive test names

2. **Test Structure**
   ```dart
   import 'package:flutter_test/flutter_test.dart';

   void main() {
     group('Bug Description - Core Logic Tests', () {
       test('Should describe expected behavior', () {
         // Arrange - Set up test data
         // Act - Execute the code
         // Assert - Verify the result
       });
     });
   }
   ```

3. **Test Key Scenarios**
   - Test initial state (empty/loading)
   - Test state after data loads
   - Test state updates
   - Test edge cases (empty data, errors)

4. **Run Tests**
   ```bash
   flutter test test/path/to/test_file.dart --reporter=expanded
   ```

### Phase 4: Analyze the Root Cause

**Common State Management Issues:**

1. **Missing `ref.watch()` in `build()` method**
   - Symptom: Provider updates but UI doesn't rebuild
   - Check: Does `build()` use `ref.watch()` for the provider?
   - Check: Is state accessed via getter using `ref.read()`?

2. **Using `ref.read()` instead of `ref.watch()`**
   - Symptom: Widget reads state once but never updates
   - Fix: Change to `ref.watch()` to establish reactive dependency

3. **Async Loading Timing Issues**
   - Symptom: Initial render shows stale/empty data
   - Check: Is `build()` called before async operation completes?

**Riverpod-Specific Issues:**

1. **Provider not watched**
   - Error: `final state = ref.read(myProvider);` in `build()`
   - Correct: `final state = ref.watch(myProvider);`

2. **State not updating**
   - Check: Is `notifier.state =` being called?
   - Check: Is notifier accessed via `ref.read(provider.notifier)`?

### Phase 5: Implement the Fix

1. **Primary Fix**
   - Add missing `ref.watch()` in `build()` method
   - Change `ref.read()` to `ref.watch()` where reactive updates are needed
   - Ensure all state that affects UI is watched

2. **Fix Example (Missing ref.watch)**
   ```dart
   // BEFORE (WRONG)
   @override
   Widget build(BuildContext context) {
     // Not watching content state
     final paragraphs = _paragraphs;  // _content.split(...)
     return Scaffold(...);
   }

   // AFTER (CORRECT)
   @override
   Widget build(BuildContext context) {
     // Watch content state to trigger rebuilds
     final contentState = ref.watch(chapterContentStateNotifierProvider);
     final paragraphs = _paragraphs;
     return Scaffold(...);
   }
   ```

3. **Defensive Fixes (Optional)**
   - Add empty state detection with user-friendly error messages
   - Improve validation logic (e.g., `trim()` checks)
   - Add loading indicators
   - Improve error handling

### Phase 6: Create Verification Tests

1. **Create Verification Test File**
   - Name: `test/**/*_fix_verification_test.dart`
   - Include tests for all fixed scenarios

2. **Test Categories**
   - Empty state detection tests
   - State update reaction tests
   - Loading state tests
   - Error handling tests
   - Integration/flow tests

3. **Run and Verify**
   ```bash
   flutter test test/path/to/verification_test.dart --reporter=expanded
   ```

### Phase 7: Document the Fix

1. **Create Fix Report**
   - Create: `test/reports/*_fix_report.md`
   - Include: Bug description, root cause, fix details, before/after comparison

2. **Document Changes**
   - List all files modified
   - Explain why each change was needed
   - Include code examples

## Debugging Checklist

When investigating UI update bugs, check:

- [ ] Does `build()` use `ref.watch()` for all state it depends on?
- [ ] Are any state getters using `ref.read()` instead of `ref.watch()`?
- [ ] Is the async operation completing before the first `build()`?
- [ ] Does the provider state actually update when data loads?
- [ ] Is the widget being rebuilt when provider state changes?
- [ ] Are there multiple providers and is the right one being watched?
- [ ] Is there a timing issue between init and first render?

## Riverpod Best Practices

1. **Always use `ref.watch()` in `build()`**
   - `ref.watch()` establishes reactive dependency
   - Widget rebuilds automatically when provider state changes

2. **Use `ref.read()` for callbacks and one-time reads**
   - In button callbacks: `ref.read(provider.notifier).doSomething()`
   - In `initState()`: `ref.read(provider)` for initialization
   - NOT in `build()` for state that affects UI

3. **State getters are not reactive**
   - Even if getter uses `ref.read()` internally
   - Must use `ref.watch()` in `build()` to trigger rebuilds

## Common Anti-Patterns

1. **State getter without ref.watch()**
   ```dart
   // WRONG
   String get _content => _controller.content;

   @override
   Widget build(BuildContext context) {
     final text = _content;  // Won't rebuild when content changes
     return Text(text);
   }
   ```

2. **Using ref.read() in build()**
   ```dart
   // WRONG
   @override
   Widget build(BuildContext context) {
     final state = ref.read(myProvider);  // Not reactive
     return Text(state.value);
   }
   ```

## Quick Diagnostic Commands

```bash
# Find all screen files
find . -name "*_screen.dart" -type f

# Find all provider files
find . -name "*_provider*.dart" -type f

# Search for ref.watch usage
grep -r "ref.watch" lib/

# Search for ref.read usage
grep -r "ref.read" lib/

# Run all tests
flutter test

# Run specific test
flutter test test/path/to/test.dart --reporter=expanded
```
