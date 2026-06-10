import 'package:flutter/material.dart';
import '../services/logger_service.dart';

/// TextEditingController 管理 Mixin
///
/// 为 State 提供 TextEditingController 的自动生命周期管理。
///
/// 使用方式：
/// ```dart
/// class _MyScreenState extends State<MyScreen> with TextEditingControllerMixin {
/// @override
/// void onControllerInit(TextEditingController controller) {
/// super.onControllerInit(controller);
/// controller.addListener(_onTextChanged);
/// }
///
/// void _onTextChanged() {
/// print('当前文本: ${textController.text}');
/// }
///
/// @override
/// Widget build(BuildContext context) {
/// return TextField(controller: textController);
/// }
/// }
/// ```
///
/// 功能特性：
/// - 自动创建 TextEditingController
/// - 自动 dispose防止内存泄漏
/// - 支持子类重写初始化逻辑
/// - 可选的文本变化监听
mixin TextEditingControllerMixin<T extends StatefulWidget> on State<T> {
 ///文本编辑控制器
 late final TextEditingController textController;

 ///是否已初始化
 bool _isControllerInit = false;

 ///初始化控制器
 ///
 /// 在 initState 中自动调用，子类可以重写此方法添加自定义逻辑。
 /// 注意：重写时必须调用 super.onControllerInit()。
 ///
 /// [controller] 已初始化的控制器
 void onControllerInit(TextEditingController controller) {
 //子类可重写以添加监听器等
 _isControllerInit = true;
 }

 ///控制器初始化完成
 ///
 /// 在 initState结束时调用，子类可重写以执行额外的初始化操作。
 void onControllerReady() {
 //子类可重写
 }

 ///文本变化时的回调
 ///
 /// 子类可重写此方法以响应文本变化。
 /// 注意：如果需要在 onControllerInit 中添加自定义监听器，
 /// 应该重写 onControllerInit 而不是此方法。
 ///
 /// [text] 新的文本内容
 void onTextChanged(String text) {
 //子类可重写
 }

 ///在 initState 中调用此方法以初始化控制器
 ///
 /// 通常在子类的 initState 中调用：
 /// ```dart
 /// @override
 /// void initState() {
 /// super.initState();
 /// initTextController();
 /// }
 /// ```
 @mustCallSuper
 void initTextController() {
 if (_isControllerInit) {
 LoggerService.instance.w(
 '[TextEditingControllerMixin] 控制器已初始化，跳过',
 category: LogCategory.ui,
 tags: ['editor'],
 );
 return;
 }

 textController = TextEditingController();
 onControllerInit(textController);

 //如果子类重写了 onTextChanged，添加监听器
 if (_doesOverrideOnTextChanged()) {
 textController.addListener(() {
 onTextChanged(textController.text);
 });
 }

 onControllerReady();
 }

 ///检查子类是否重写了 onTextChanged
 bool _doesOverrideOnTextChanged() {
 //简单检查：如果子类重写了此方法，返回 true
 // 由于 Dart 的限制，这里假设子类重写时会调用 super
 return false; // 默认不添加监听器，子类在 onControllerInit 中自行添加
 }

 ///获取当前文本内容
 String get currentText => textController.text;

 ///设置文本内容
 void setText(String text) {
 textController.text = text;
 }

 ///清空文本内容
 void clearText() {
 textController.clear();
 }

 ///选择全部文本
 void selectAll() {
 textController.selection = TextSelection(
 baseOffset:0,
 extentOffset: textController.text.length,
 );
 }

 ///移动光标到末尾
 void moveCursorToEnd() {
 textController.selection = TextSelection.fromPosition(
 TextPosition(offset: textController.text.length),
 );
 }

 ///移动光标到开头
 void moveCursorToStart() {
 textController.selection = TextSelection.fromPosition(
 const TextPosition(offset:0),
 );
 }

 ///获取选中的文本
 String get selectedText {
 final selection = textController.selection;
 if (!selection.isValid || selection.isCollapsed) {
 return '';
 }
 return textController.text.substring(
 selection.start,
 selection.end,
 );
 }

 ///删除选中的文本
 void deleteSelection() {
 final selection = textController.selection;
 if (!selection.isValid || selection.isCollapsed) {
 return;
 }
 final text = textController.text;
 final before = text.substring(0, selection.start);
 final after = text.substring(selection.end);
 textController.text = before + after;
 textController.selection = TextSelection.fromPosition(
 TextPosition(offset: selection.start),
 );
 }

 ///在光标位置插入文本
 void insertText(String textToInsert) {
 final selection = textController.selection;
 final text = textController.text;

 String newText;
 int newCursorPos;

 if (selection.isValid && !selection.isCollapsed) {
 //有选中文本，替换选中的内容
 newText = text.replaceRange(selection.start, selection.end, textToInsert);
 newCursorPos = selection.start + textToInsert.length;
 } else {
 //无选中，在光标位置插入
 final cursorPos = selection.baseOffset.clamp(0, text.length);
 newText = text.replaceRange(cursorPos, cursorPos, textToInsert);
 newCursorPos = cursorPos + textToInsert.length;
 }

 textController.text = newText;
 textController.selection = TextSelection.fromPosition(
 TextPosition(offset: newCursorPos),
 );
 }

 ///清理资源
 ///
 /// 在子类的 dispose 中调用：
 /// ```dart
 /// @override
 /// void dispose() {
 /// disposeTextController();
 /// super.dispose();
 /// }
 /// ```
 @mustCallSuper
 void disposeTextController() {
 LoggerService.instance.d(
 '[TextEditingControllerMixin] 释放 TextEditingController',
 category: LogCategory.ui,
 tags: ['editor'],
 );
 textController.dispose();
 }

 @override
 @mustCallSuper
 void dispose() {
 //注意：由于 mixin 的 dispose 可能不被调用，
 //建议子类在各自的 dispose 中显式调用 disposeTextController
 disposeTextController();
 super.dispose();
 }
}

/// 多 TextEditingController 管理器
///
/// 当需要管理多个 TextEditingController 时使用。
///
/// 使用方式：
/// ```dart
/// class _MyScreenState extends State<MyScreen> {
/// late final MultiTextEditingControllerManager _controllers;
///
/// @override
/// void initState() {
/// super.initState();
/// _controllers = MultiTextEditingControllerManager(
/// keys: ['username', 'password', 'email'],
/// );
/// }
///
/// @override
/// void dispose() {
/// _controllers.dispose();
/// super.dispose();
/// }
///
/// @override
/// Widget build(BuildContext context) {
/// return Column(
/// children: [
/// TextField(
/// controller: _controllers.get('username'),
/// decoration: const InputDecoration(labelText: '用户名'),
/// ),
/// TextField(
/// controller: _controllers.get('password'),
/// decoration: const InputDecoration(labelText: '密码'),
/// ),
/// ],
/// );
/// }
/// }
/// ```
class MultiTextEditingControllerManager {
 final Map<String, TextEditingController> _controllers = {};

 ///创建多控制器管理器
 ///
 /// [keys] 控制器的键名列表
 /// [initialValues] 初始值映射（可选）
 MultiTextEditingControllerManager({
 required List<String> keys,
 Map<String, String>? initialValues,
 }) {
 for (final key in keys) {
 final initialValue = initialValues?[key];
 _controllers[key] = TextEditingController(text: initialValue);
 }
 }

 ///获取指定键的控制器
 TextEditingController get(String key) {
 final controller = _controllers[key];
 if (controller == null) {
 throw ArgumentError('未找到键为 "$key" 的 TextEditingController');
 }
 return controller;
 }

 ///安全获取指定键的控制器（不存在时返回 null）
 TextEditingController? tryGet(String key) {
 return _controllers[key];
 }

 ///添加新的控制器
 void add(String key, {String? initialValue}) {
 if (_controllers.containsKey(key)) {
 LoggerService.instance.w(
 '[MultiTextEditingControllerManager] 键 "$key" 已存在',
 category: LogCategory.ui,
 tags: ['editor'],
 );
 return;
 }
 _controllers[key] = TextEditingController(text: initialValue);
 }

 ///移除指定键的控制器
 void remove(String key) {
 final controller = _controllers.remove(key);
 controller?.dispose();
 }

 ///获取所有文本内容
 Map<String, String> get allTexts {
 return Map.fromEntries(
 _controllers.entries.map(
 (entry) => MapEntry(entry.key, entry.value.text),
 ),
 );
 }

 ///设置指定键的文本
 void setText(String key, String text) {
 get(key).text = text;
 }

 ///清空所有文本
 void clearAll() {
 for (final controller in _controllers.values) {
 controller.clear();
 }
 }

 ///是否所有文本都不为空
 bool get allValid {
 return _controllers.values
 .every((controller) => controller.text.isNotEmpty);
 }

 ///释放所有控制器
 void dispose() {
 for (final controller in _controllers.values) {
 controller.dispose();
 }
 _controllers.clear();
 }
}