import 'dart:async';
import 'package:flutter/material.dart';
import '../services/logger_service.dart';

/// Stream 订阅管理 Mixin
///
/// 为 State 提供 Stream 订阅的自动生命周期管理，
/// 防止因忘记取消订阅而导致的内存泄漏。
///
/// 使用方式：
/// ```dart
/// class _MyScreenState extends State<MyScreen> with StreamSubscriptionMixin {
/// late final StreamController<String> _controller;
///
/// @override
/// void initState() {
/// super.initState();
/// _controller = StreamController<String>();
///
/// //添加订阅，自动管理生命周期
/// addSubscription(
/// _controller.stream.listen((data) {
/// print('收到数据: $data');
/// }),
/// );
/// }
///
/// void sendData() {
/// _controller.add('Hello');
/// }
///
/// @override
/// void dispose() {
/// _controller.close();
/// super.dispose(); // StreamSubscriptionMixin 会自动取消所有订阅
/// }
/// }
/// ```
///
/// 功能特性：
/// - 自动管理 Stream 订阅生命周期
/// - dispose 时自动取消所有订阅
/// - 支持批量添加订阅
/// - 提供订阅状态查询
mixin StreamSubscriptionMixin<T extends StatefulWidget> on State<T> {
 /// 所有活跃的 Stream 订阅
 final List<StreamSubscription> _subscriptions = [];

 /// 所有活跃的 StreamController（可选管理）
 final List<StreamController> _controllers = [];

 /// 订阅数量
 int get subscriptionCount => _subscriptions.length;

 /// 是否有活跃订阅
 bool get hasActiveSubscription => _subscriptions.isNotEmpty;

 /// 添加 Stream 订阅
 ///
 /// 添加的订阅会在 dispose 时自动取消。
 ///
 /// [subscription] 要添加的 Stream 订阅
 /// 返回传入的订阅，支持链式调用
 StreamSubscription addSubscription(StreamSubscription subscription) {
 _subscriptions.add(subscription);
 return subscription;
 }

 /// 批量添加 Stream 订阅
 ///
 /// 一次添加多个订阅。
 ///
 /// [subscriptions] 要添加的 Stream 订阅列表
 void addSubscriptions(List<StreamSubscription> subscriptions) {
 _subscriptions.addAll(subscriptions);
 }

 /// 订阅 Stream 并自动管理
 ///
 ///便捷方法：直接订阅 Stream 并自动管理订阅。
 ///
 /// [S] Stream 数据类型
 /// [stream] 要订阅的 Stream
 /// [onData] 数据回调
 /// [onError]错误回调
 /// [onDone] 完成回调
 /// [cancelOnError] 发生错误时是否取消订阅
 ///
 /// 返回创建的订阅
 StreamSubscription subscribe<S>({
 required Stream<S> stream,
 void Function(S data)? onData,
 Function? onError,
 void Function()? onDone,
 bool cancelOnError = false,
 }) {
 final subscription = stream.listen(
 onData,
 onError: onError,
 onDone: onDone,
 cancelOnError: cancelOnError,
 );
 return addSubscription(subscription);
 }

 /// 取消指定索引的订阅
 ///
 /// [index] 订阅索引
 bool cancelSubscriptionAt(int index) {
 if (index <0 || index >= _subscriptions.length) {
 LoggerService.instance.w(
 '[StreamSubscriptionMixin] 索引 $index 超出范围',
 category: LogCategory.general,
 tags: ['subscription'],
 );
 return false;
 }

 final subscription = _subscriptions.removeAt(index);
 subscription.cancel();
 return true;
 }

 /// 取消所有订阅
 ///
 /// 通常不需要手动调用，dispose 时会自动执行。
 void cancelAllSubscriptions() {
 for (final subscription in _subscriptions) {
 subscription.cancel();
 }
 _subscriptions.clear();
 }

 /// 添加 StreamController 管理（可选）
 ///
 /// 管理的 StreamController 会在 dispose 时自动关闭。
 ///
 /// [controller] 要管理的 StreamController
 void addController(StreamController controller) {
 _controllers.add(controller);
 }

 /// 关闭并移除所有管理的 StreamController
 void closeAllControllers() {
 for (final controller in _controllers) {
 controller.close();
 }
 _controllers.clear();
 }

 ///清除所有资源
 ///
 /// 取消所有订阅并关闭所有控制器。
 /// 通常在 dispose 时自动调用。
 @mustCallSuper
 void cleanupSubscriptions() {
 LoggerService.instance.d(
 '[StreamSubscriptionMixin] 清理 $_subscriptions.length 个订阅',
 category: LogCategory.general,
 tags: ['subscription'],
 );
 cancelAllSubscriptions();
 closeAllControllers();
 }

 @override
 @mustCallSuper
 void dispose() {
 cleanupSubscriptions();
 super.dispose();
 }
}

///周期定时器管理 Mixin
///
/// 为 State 提供 Timer 的自动生命周期管理。
///
/// 使用方式：
/// ```dart
/// class _MyScreenState extends State<MyScreen> with TimerMixin {
/// @override
/// void initState() {
/// super.initState();
/// //每秒执行一次
/// startPeriodicTimer(
/// const Duration(seconds:1),
/// () => print('定时器触发'),
/// );
/// }
/// }
/// ```
mixin TimerMixin<T extends StatefulWidget> on State<T> {
 ///活跃的定时器列表
 final List<Timer> _timers = [];

 ///活跃的周期定时器列表
 final List<Timer> _periodicTimers = [];

 /// 定时器数量
 int get timerCount => _timers.length + _periodicTimers.length;

 ///启动一次性定时器
 ///
 /// [duration] 延迟时间
 /// [callback] 回调函数
 Timer startTimer({
 required Duration duration,
 required VoidCallback callback,
 }) {
 final timer = Timer(duration, callback);
 _timers.add(timer);
 return timer;
 }

 ///启动周期定时器
 ///
 /// [duration] 周期时间
 /// [callback] 回调函数
 Timer startPeriodicTimer({
 required Duration duration,
 required VoidCallback callback,
 }) {
 final timer = Timer.periodic(duration, (_) => callback());
 _periodicTimers.add(timer);
 return timer;
 }

 /// 取消指定的一次性定时器
 bool cancelTimer(Timer timer) {
 if (_timers.remove(timer)) {
 timer.cancel();
 return true;
 }
 return false;
 }

 /// 取消指定的周期性定时器
 bool cancelPeriodicTimer(Timer timer) {
 if (_periodicTimers.remove(timer)) {
 timer.cancel();
 return true;
 }
 return false;
 }

 /// 取消所有定时器
 void cancelAllTimers() {
 for (final timer in _timers) {
 timer.cancel();
 }
 for (final timer in _periodicTimers) {
 timer.cancel();
 }
 _timers.clear();
 _periodicTimers.clear();
 }

 @override
 @mustCallSuper
 void dispose() {
 cancelAllTimers();
 super.dispose();
 }
}

/// Future 超时管理工具
///
/// 为异步操作提供超时控制。
class FutureTimeout {
 /// 为 Future 添加超时限制
 ///
 /// [future] 要包装的 Future
 /// [timeout] 超时时间
 /// [onTimeout] 超时回调
 ///
 /// 返回带有超时控制的 Future
 static Future<T> withTimeout<T>({
 required Future<T> future,
 required Duration timeout,
 FutureOr<T> Function()? onTimeout,
 }) {
 return future.timeout(
 timeout,
 onTimeout: onTimeout,
 );
 }

 /// 为 Future 添加默认超时异常
 ///
 /// [future] 要包装的 Future
 /// [timeout] 超时时间
 /// [message] 超时错误消息
 ///
 /// 返回带有超时控制的 Future，超时抛出 TimeoutException
 static Future<T> withTimeoutException<T>({
 required Future<T> future,
 required Duration timeout,
 String message = '操作超时',
 }) {
 return future.timeout(
 timeout,
 onTimeout: () => throw TimeoutException(message, timeout),
 );
 }
}

/// 异步操作重试工具
class AsyncRetry {
 /// 重试异步操作
 ///
 /// [fn] 要执行的异步操作
 /// [maxAttempts] 最大尝试次数（默认3）
 /// [delay] 重试延迟（默认1秒）
 /// [retryIf] 重试条件函数，返回 true 表示继续重试
 ///
 /// 返回操作结果，所有尝试失败后抛出最后一个异常
 static Future<T> retry<T>({
 required Future<T> Function() fn,
 int maxAttempts =3,
 Duration delay = const Duration(seconds:1),
 bool Function(Object error)? retryIf,
 }) async {
 Object? lastError;

 for (int attempt =1; attempt <= maxAttempts; attempt++) {
 try {
 return await fn();
 } catch (e) {
 lastError = e;
 final shouldRetry = retryIf?.call(e) ?? true;

 if (attempt < maxAttempts && shouldRetry) {
 LoggerService.instance.w(
 '[AsyncRetry] 第 $attempt 次尝试失败: $e，${delay.inSeconds}秒后重试...',
 category: LogCategory.general,
 tags: ['subscription'],
 );
 await Future.delayed(delay);
 } else {
 LoggerService.instance.e(
 '[AsyncRetry] 所有 $maxAttempts 次尝试均失败',
 category: LogCategory.general,
 tags: ['subscription'],
 );
 rethrow;
 }
 }
 }

 throw lastError ?? Exception('重试失败');
 }
}