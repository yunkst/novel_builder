# Riverpod Best Practices and Common Patterns

## Core Concepts

### ref.watch() - Reactive State Reading

**When to use**: In `build()` methods for state that affects UI

```dart
@override
Widget build(BuildContext context) {
  // ✅ CORRECT: Watch the provider to establish reactive dependency
  final state = ref.watch(myProvider);

  // When myProvider changes, this widget will rebuild automatically
  return Text(state.value);
}
```

**Key points**:
- Can ONLY be used inside `build()` methods
- Establishes a reactive dependency between widget and provider
- Widget rebuilds automatically when provider state changes
- Returns the current state value

### ref.read() - One-Time State Reading

**When to use**: In callbacks, initialization, or one-time operations

```dart
// ✅ CORRECT: In button callbacks
ElevatedButton(
  onPressed: () {
    // Read notifier to trigger state change
    ref.read(myProvider.notifier).doSomething();
  },
  child: Text('Action'),
)

// ✅ CORRECT: In initState()
@override
void initState() {
  super.initState();
  // One-time read for initialization
  final initialState = ref.read(myProvider);
  // Do something with initialState...
}
```

**Key points**:
- Can be used anywhere (callbacks, methods, init, etc.)
- Does NOT establish reactive dependency
- Reads the current state value once
- Does NOT trigger rebuild when state changes

### ref.listen() - Side Effects

**When to use**: To respond to state changes with side effects (navigation, dialogs, logging)

```dart
@override
Widget build(BuildContext context) {
  // Listen to state changes
  ref.listen<MyState>(
    myProvider,
    (previous, next) {
      // Handle state change
      if (next.hasError) {
        showErrorDialog(context, next.error);
      }
    },
  );

  return SomeWidget();
}
```

## Common Patterns

### Pattern 1: Watching Multiple Providers

```dart
@override
Widget build(BuildContext context) {
  // Watch multiple providers
  final userState = ref.watch(userProvider);
  final settingsState = ref.watch(settingsProvider);
  final contentState = ref.watch(contentProvider);

  return Column(
    children: [
      Text(userState.name),
      Text(settingsState.theme),
      Text(contentState.text),
    ],
  );
}
```

### Pattern 2: Selecting Specific State

```dart
@override
Widget build(BuildContext context) {
  // Watch only the part of state you need
  final userName = ref.watch(userProvider.select((state) => state.name));

  // Widget only rebuilds when user.name changes, not other user properties
  return Text(userName);
}
```

### Pattern 3: Watching Notifier for Methods

```dart
@override
Widget build(BuildContext context) {
  final notifier = ref.watch(myProvider.notifier);

  return ElevatedButton(
    onPressed: () => notifier.doSomething(),
    child: Text('Action'),
  );
}
```

### Pattern 4: Conditional State Reading

```dart
@override
Widget build(BuildContext context) {
  final state = ref.watch(myProvider);

  // Handle different states
  if (state.isLoading) {
    return CircularProgressIndicator();
  }

  if (state.hasError) {
    return Text('Error: ${state.error}');
  }

  return ContentWidget(data: state.data);
}
```

## Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Using ref.read() in build()

```dart
@override
Widget build(BuildContext context) {
  // ❌ WRONG: Using ref.read() in build()
  final state = ref.read(myProvider);

  return Text(state.value);
}

// Problem: Widget won't rebuild when myProvider changes
// Fix: Use ref.watch() instead
```

### ❌ Anti-Pattern 2: State Getter Without ref.watch()

```dart
class MyWidget extends ConsumerStatefulWidget {
  String get _content => _contentController.content;
  //                 └─> Uses ref.read() internally

  @override
  Widget build(BuildContext context) {
    // ❌ WRONG: Using getter without watching the provider
    final text = _content;

    return Text(text);
  }
}

// Problem: build() won't rebuild when content changes
// Fix: Add ref.watch(contentStateProvider) in build()
```

### ❌ Anti-Pattern 3: Watching Parent Instead of Data Provider

```dart
@override
Widget build(BuildContext context) {
  // ❌ WRONG: Watching parent provider
  ref.watch(parentProvider);

  // Then accessing child data via getter
  final data = _childData;

  return Text(data);
}

// Problem: Widget only rebuilds when parent changes, not child
// Fix: Watch the actual data provider you need
```

### ❌ Anti-Pattern 4: Async Operations Without Loading State

```dart
@override
void initState() {
  super.initState();

  // ❌ WRONG: Async operation without watching loading state
  _loadData();
}

Future<void> _loadData() async {
  final data = await apiService.fetchData();
  // Update provider...

  // Problem: build() might run before data loads
  // Fix: Watch loading state in build()
}

// Fix:
@override
Widget build(BuildContext context) {
  final state = ref.watch(dataProvider);

  if (state.isLoading) {
    return CircularProgressIndicator();
  }

  return DataWidget(data: state.data);
}
```

## Provider Types and When to Use Each

### 1. Provider - Simple Values

```dart
final configProvider = Provider<Config>((ref) {
  return Config();
});

// Usage: Read-only access
final config = ref.watch(configProvider);
```

### 2. StateNotifier - Mutable State

```dart
final myStateNotifierProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier();
});

// Usage: Watch state
final state = ref.watch(myStateNotifierProvider);

// Usage: Access notifier
ref.read(myStateNotifierProvider.notifier).doSomething();
```

### 3. StateProvider - Simple Mutable State

```dart
final counterProvider = StateProvider<int>((ref) => 0);

// Usage: Watch value
final count = ref.watch(counterProvider);

// Usage: Update value
ref.read(counterProvider.notifier).state++;
```

### 4. FutureProvider - Async Values

```dart
final dataProvider = FutureProvider<Data>((ref) async {
  final response = await http.get('url');
  return Data.fromJson(response.data);
});

// Usage: Watch async state
final asyncValue = ref.watch(dataProvider);

return asyncValue.when(
  data: (data) => DataWidget(data),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => Text('Error: $error'),
);
```

### 5. StreamProvider - Stream Values

```dart
final messagesProvider = StreamProvider<List<Message>>((ref) {
  return messageStream;
});

// Usage: Watch stream
final asyncValue = ref.watch(messagesProvider);

return asyncValue.when(
  data: (messages) => MessagesList(messages),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => Text('Error: $error'),
);
```

## Testing with Riverpod

### Unit Testing Providers

```dart
test('should update state', () {
  // Arrange
  final container = ProviderContainer();

  // Act
  container.read(myProvider.notifier).increment();

  // Assert
  expect(container.read(myProvider).value, 1);
});
```

### Widget Testing with Providers

```dart
testWidgets('should display data from provider', (tester) async {
  // Arrange
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myProvider.overrideWithValue(testData),
      ],
      child: MyApp(),
    ),
  );

  // Assert
  expect(find.text('Test Data'), findsOneWidget);
});
```

## Performance Optimization

### 1. Use select() to Watch Specific Values

```dart
@override
Widget build(BuildContext context) {
  // Only rebuilds when user.name changes
  final userName = ref.watch(userProvider.select((s) => s.name));

  return Text(userName);
}
```

### 2. Avoid Watching Unnecessary Providers

```dart
@override
Widget build(BuildContext context) {
  // ❌ BAD: Watching more than needed
  final state = ref.watch(largeStateProvider);
  return Text(state.smallField);

  // ✅ GOOD: Select only what's needed
  final field = ref.watch(largeStateProvider.select((s) => s.smallField));
  return Text(field);
}
```

### 3. Use const Constructors

```dart
@override
Widget build(BuildContext context) {
  return const MyWidget(); // const helps avoid unnecessary rebuilds
}
```

## Debugging Tips

### 1. Enable Riverpod Logging

```dart
void main() {
  // Enable debug logs
  ProviderScope.debugObservatoryEnabled = true;

  runApp(ProviderScope(child: MyApp()));
}
```

### 2. Check Provider Dependencies

```dart
// In build(), verify you're watching the right provider
@override
Widget build(BuildContext context) {
  final state = ref.watch(myProvider); // Breakpoint here

  // Check if state has expected values
  debugPrint('State: $state');

  return MyWidget();
}
```

### 3. Verify State Updates

```dart
// In notifier, add logging
class MyNotifier extends StateNotifier<MyState> {
  MyNotifier() : super(MyState.initial());

  void updateState() {
    debugPrint('Before update: $state');
    state = MyState.updated();
    debugPrint('After update: $state');
  }
}
```

## Common Error Messages

### "setState() called after dispose()"
**Cause**: Async operation completing after widget is disposed
**Fix**: Check `mounted` before setState or use `ref.read()` instead

### "Bad state: Cannot add new events after calling close"
**Cause**: Adding to StreamController after it's closed
**Fix**: Cancel subscriptions in dispose()

### "Package riverpod has not been initialized"
**Cause**: Not wrapped in ProviderScope
**Fix**: Wrap root widget in ProviderScope

## Checklist for New Features

When adding new features with Riverpod:

- [ ] Define provider with appropriate type (Provider/StateNotifier/etc.)
- [ ] Use `ref.watch()` in `build()` to watch state
- [ ] Use `ref.read()` in callbacks and init methods
- [ ] Handle loading, error, and data states
- [ ] Add tests for provider logic
- [ ] Add tests for widget integration
- [ ] Verify widget rebuilds when state changes
- [ ] Check for unnecessary rebuilds
- [ ] Document provider usage
- [ ] Add debug logging if needed
