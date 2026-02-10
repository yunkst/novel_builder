# Flutter Bug Fix Debugging Checklist

Use this checklist when debugging Flutter state management and UI update issues.

## Initial Information Gathering

### Bug Symptoms
- [ ] What does the user see?
- [ ] What does the user expect to see?
- [ ] Is the data actually loaded (check logs, network tab, database)?
- [ ] Does the bug happen consistently or intermittently?
- [ ] What actions trigger the bug?
- [ ] When did the bug first appear?

### Key Indicator Questions
- [ ] User says "data is not empty but screen is blank" → Likely state management issue
- [ ] User says "UI doesn't update after..." → Likely missing ref.watch()
- [ ] User says "sometimes it works" → Likely timing or race condition
- [ ] User says "works after refresh/restart" → Likely initialization issue

## Code Inspection Checklist

### Widget (Screen/Page) Analysis

#### build() Method
- [ ] Does `build()` use `ref.watch()` for all state it depends on?
- [ ] Are any state getters being used without `ref.watch()`?
- [ ] Is `ref.read()` used incorrectly in `build()`?
- [ ] Does `build()` handle loading, error, and data states?
- [ ] Are all necessary providers being watched?

#### State Getters
- [ ] Check if state getters use `ref.read()` internally
- [ ] Verify getters are watched via `ref.watch()` in `build()`
- [ ] Ensure getter dependencies are established

#### Lifecycle Methods
- [ ] Does `initState()` initialize correctly?
- [ ] Are async operations started in `initState()`?
- [ ] Does `dispose()` clean up resources?
- [ ] Are there `addPostFrameCallback` calls that affect timing?

### Provider Analysis

#### Provider Definitions
- [ ] Is the provider defined with correct type?
- [ ] Does the provider update its state correctly?
- [ ] Is `notifier.state =` being called when it should?
- [ ] Are there multiple providers that should be watched?

#### State Notifiers
- [ ] Does the notifier have correct initial state?
- [ ] Do state transition methods work correctly?
- [ ] Is state immutable when it should be?
- [ ] Are error states handled properly?

#### Provider Watching
- [ ] Is the correct provider being watched?
- [ ] Are parent/child provider relationships correct?
- [ ] Are providers being overridden in tests?
- [ ] Are there circular dependencies?

### Data Flow Analysis

#### Data Loading
- [ ] Is data loaded from API/Database correctly?
- [ ] Is loading state set to true during load?
- [ ] Is loading state set to false after load?
- [ ] Is error state set if load fails?

#### State Updates
- [ ] Does state update when data loads?
- [ ] Do multiple state updates work correctly?
- [ ] Are state updates atomic when needed?
- [ ] Is the update timing correct?

#### UI Response
- [ ] Does UI rebuild when state changes?
- [ ] Are all widgets affected by state rebuilding?
- [ ] Are there widgets that should rebuild but don't?
- [ ] Are there widgets rebuilding unnecessarily?

## Common Issues Checklist

### Issue: Blank Screen
- [ ] Check: Does `build()` watch the content provider?
- [ ] Check: Is `ref.watch()` missing for critical state?
- [ ] Check: Is content actually loaded (not empty)?
- [ ] Check: Does `build()` handle empty state correctly?
- [ ] Check: Is there a timing issue with async load?

### Issue: Stale Data
- [ ] Check: Does the provider update its state?
- [ ] Check: Is `ref.watch()` established for that state?
- [ ] Check: Is there caching that's not invalidated?
- [ ] Check: Are old widgets being reused?

### Issue: Widget Not Rebuilding
- [ ] Check: Is `ref.watch()` used in `build()`?
- [ ] Check: Is the correct provider being watched?
- [ ] Check: Does the provider state actually change?
- [ ] Check: Is const preventing rebuild?

### Issue: Unnecessary Rebuilds
- [ ] Check: Can you use `select()` to watch specific values?
- [ ] Check: Are you watching more providers than needed?
- [ ] Check: Can you extract widgets to reduce rebuilds?
- [ ] Check: Are providers being watched that never change?

## Testing Checklist

### Unit Tests
- [ ] Test provider initial state
- [ ] Test state transitions
- [ ] Test state update methods
- [ ] Test error handling
- [ ] Test edge cases (empty, null, large data)

### Widget Tests
- [ ] Test widget renders with initial state
- [ ] Test widget rebuilds on state change
- [ ] Test loading state display
- [ ] Test error state display
- [ ] Test user interactions

### Integration Tests
- [ ] Test complete user flows
- [ ] Test async data loading
- [ ] Test state persistence
- [ ] Test navigation with state
- [ ] Test error recovery

## Debugging Steps

### Step 1: Verify Data is Loaded
```bash
# Check logs for data loading
flutter run --verbose

# Look for:
# - API responses
# - Database queries
# - State updates
# - Provider state changes
```

### Step 2: Check Provider State
```dart
// Add debug logging
@override
Widget build(BuildContext context) {
  final state = ref.watch(myProvider);
  debugPrint('Current state: $state'); // Add this
  return MyWidget();
}
```

### Step 3: Verify Rebuilds
```dart
// Add logging to track rebuilds
@override
Widget build(BuildContext context) {
  debugPrint('Building: ${widget.runtimeType}'); // Add this
  // ...
}
```

### Step 4: Check Timing
```dart
// Add timestamps to operations
debugPrint('${DateTime.now()(): initState called');
debugPrint('${DateTime.now()(): Data loaded');
debugPrint('${DateTime.now()(): build called');
```

### Step 5: Verify Provider Watching
```dart
// Test by removing ref.watch() temporarily
@override
Widget build(BuildContext context) {
  // Temporarily use ref.read() to see current value
  final state = ref.read(myProvider);
  debugPrint('State: $state (using ref.read())');
  // ...
}
```

## Diagnostic Commands

```bash
# Find all provider definitions
find lib -name "*_provider*.dart"

# Find ref.watch usage
grep -r "ref.watch" lib/

# Find ref.read usage (potential issues)
grep -r "ref.read" lib/

# Search for specific provider
grep -r "MyProvider" lib/

# Run tests with coverage
flutter test --coverage

# Analyze code
flutter analyze
```

## Common Fixes

### Fix 1: Add Missing ref.watch()
```dart
// BEFORE
@override
Widget build(BuildContext context) {
  final data = _data; // From getter using ref.read()
  return Text(data);
}

// AFTER
@override
Widget build(BuildContext context) {
  ref.watch(dataProvider); // Establish reactive dependency
  final data = _data;
  return Text(data);
}
```

### Fix 2: Change ref.read() to ref.watch()
```dart
// BEFORE
@override
Widget build(BuildContext context) {
  final state = ref.read(myProvider);
  return Text(state.value);
}

// AFTER
@override
Widget build(BuildContext context) {
  final state = ref.watch(myProvider);
  return Text(state.value);
}
```

### Fix 3: Watch Correct Provider
```dart
// BEFORE
@override
Widget build(BuildContext context) {
  ref.watch(parentProvider);
  final childData = _childData; // Wrong provider
  return Text(childData);
}

// AFTER
@override
Widget build(BuildContext context) {
  ref.watch(childDataProvider); // Correct provider
  final childData = _childData;
  return Text(childData);
}
```

### Fix 4: Handle Loading State
```dart
// BEFORE
@override
Widget build(BuildContext context) {
  final data = ref.watch(dataProvider);
  return DataWidget(data); // Crashes if null
}

// AFTER
@override
Widget build(BuildContext context) {
  final asyncValue = ref.watch(dataProvider);

  return asyncValue.when(
    data: (data) => DataWidget(data),
    loading: () => CircularProgressIndicator(),
    error: (error, stack) => Text('Error: $error'),
  );
}
```

## Verification

After applying fixes:

- [ ] Run tests: `flutter test`
- [ ] Check for errors: `flutter analyze`
- [ ] Test on device/emulator
- [ ] Verify with actual data
- [ ] Test edge cases
- [ ] Check performance
- [ ] Verify no regressions

## Documentation

After fixing the bug:

- [ ] Document root cause
- [ ] Document the fix
- [ ] Add tests to prevent regression
- [ ] Update code comments if needed
- [ ] Create fix report in test/reports/
- [ ] Share lessons learned with team

## Prevention

To prevent similar bugs:

- [ ] Always use `ref.watch()` in `build()` for reactive state
- [ ] Use `ref.read()` only for callbacks and one-time reads
- [ ] Write tests for state changes
- [ ] Add debug logging for complex flows
- [ ] Review provider dependencies regularly
- [ ] Use type-safe provider patterns
- [ ] Handle loading/error states explicitly
- [ ] Document provider usage in code
