/// 表单验证工具使用示例
///
/// 本文件演示了如何使用项目中的表单验证工具类，包括：
/// - [FormValidator] - 链式表单验证器
/// - [InputFormatter] - 输入格式化器
/// - [ValidationResult] - 验证结果封装
///
/// 导入：
/// ```dart
/// import 'package:novel_app/utils/form_validator.dart';
/// import 'package:novel_app/utils/input_formatter.dart';
/// import 'package:novel_app/utils/validation_result.dart';
/// ```
library;

import 'package:flutter/material.dart';
import 'form_validator.dart';
import 'input_formatter.dart';
import 'validation_result.dart';

// ==================== 示例1：基础表单验证 ====================

/// 基础验证示例 - 用户名验证
void example1BasicValidation() {
  // 场景：验证用户名
  // 规则：不能为空，3-20个字符

  final username = 'John';

  final result = FormValidator.validate('用户名', username)
      .required()
      .minLength(3)
      .maxLength(20)
      .result();

  if (result.isValid) {
    debugPrint('验证通过: $username');
  } else {
    debugPrint('验证失败: ${result.errorMessage}');
    // 输出: 验证失败: 用户名长度不能少于3个字符
  }
}

/// URL验证示例
void example2UrlValidation() {
  // 场景：验证小说URL
  final novelUrl = 'https://example.com/novel/123';

  final result =
      FormValidator.validate('小说URL', novelUrl).required().url().result();

  if (!result.isValid) {
    debugPrint('URL格式错误: ${result.errorMessage}');
  }
}

/// 数字范围验证示例
void example3NumberRangeValidation() {
  // 场景：验证章节号（1-9999）
  final chapterNumber = '100';

  final result = FormValidator.validate('章节号', chapterNumber)
      .required()
      .number()
      .range(min: 1, max: 9999)
      .result();

  if (result.isValid) {
    debugPrint('章节号有效: $chapterNumber');
  }
}

/// 邮箱验证示例
void example4EmailValidation() {
  final email = 'user@example.com';

  final result =
      FormValidator.validate('邮箱', email).required().email().result();

  debugPrint(result.isValid ? '邮箱有效' : result.errorMessage);
}

// ==================== 示例2：角色名称防重复验证 ====================

/// 角色名称验证（参考 character_input_dialog.dart）
void example5CharacterNameValidation() {
  // 场景：创建角色时验证名称不重复
  final existingCharacters = ['张三', '李四', '王五'];
  final newName = '张三';

  final result = FormValidator.validate('角色名称', newName)
      .required()
      .minLength(2)
      .maxLength(20)
      .unique(existingCharacters)
      .result();

  if (!result.isValid) {
    debugPrint('角色名称重复: ${result.errorMessage}');
    // 输出: 角色名称重复: 角色名称已存在，请使用其他值
  }
}

/// 批量角色名称验证
void example6BatchCharacterNameValidation() {
  final existingCharacters = ['张三', '李四', '王五'];
  final newNames = ['赵六', '张三', '钱七'];

  // 批量验证新角色名是否重复
  for (final name in newNames) {
    final result = FormValidator.validate('角色名称', name)
        .unique(existingCharacters, message: '角色名"$name"已存在')
        .result();

    if (!result.isValid) {
      debugPrint(result.errorMessage);
    }
  }
}

// ==================== 示例3：多字段表单验证 ====================

/// 沉浸体验配置验证（参考 immersive_setup_dialog.dart）
void example7MultiFieldValidation() {
  // 场景：验证沉浸体验配置对话框输入
  final userRequirement = '我想体验悬疑场景';
  final selectedRoles = ['张三', '李四'];
  final userRole = '张三';

  final validatorGroup = FormValidatorGroup();

  // 验证用户要求
  validatorGroup
      .field('体验要求', userRequirement)
      .required()
      .minLength(10, message: '描述至少需要10个字符');

  // 验证角色选择（集合验证）
  if (selectedRoles.isEmpty) {
    debugPrint('请至少选择一个角色');
  }

  // 验证用户角色选择
  if (!selectedRoles.contains(userRole)) {
    debugPrint('您扮演的角色必须在参与角色中');
  }

  // 执行所有验证
  final result = validatorGroup.validateAll();
  if (!result.isValid) {
    debugPrint('验证失败: ${result.errorMessage}');
  }
}

/// 注册表单验证
void example8RegistrationFormValidation() {
  final username = 'newuser';
  final email = 'user@example.com';
  final password = 'Pass123';
  final confirmPassword = 'Pass123';

  final validatorGroup = FormValidatorGroup();

  validatorGroup.field('用户名', username).required().minLength(3).maxLength(20);

  validatorGroup.field('邮箱', email).required().email();

  validatorGroup
      .field('密码', password)
      .required()
      .minLength(8)
      .password(requireUppercase: true, requireNumber: true);

  // 验证确认密码（自定义验证）
  validatorGroup.field('确认密码', confirmPassword).custom((value) {
    if (value != password) {
      return '两次输入的密码不一致';
    }
    return null;
  });

  final result = validatorGroup.validateAll();
  if (result.isValid) {
    debugPrint('注册信息验证通过');
  } else {
    debugPrint('验证失败: ${result.errorMessage}');
  }
}

// ==================== 示例4：与 TextFormField 集成 ====================

/// 在 TextFormField 中使用验证
class Example9TextFormFieldIntegration extends StatefulWidget {
  const Example9TextFormFieldIntegration({super.key});

  @override
  State<Example9TextFormFieldIntegration> createState() =>
      _Example9TextFormFieldIntegrationState();
}

class _Example9TextFormFieldIntegrationState
    extends State<Example9TextFormFieldIntegration> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // 方法1：使用快速验证器
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              border: OutlineInputBorder(),
            ),
            validator: (value) => QuickValidator.lengthRange(
              value,
              3,
              20,
              fieldName: '用户名',
            ),
          ),

          const SizedBox(height: 16),

          // 方法2：使用 FormValidator
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: '邮箱',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final validator = FormValidator.validate('邮箱', value);
              validator.required().email();
              return validator.result().errorMessage;
            },
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                debugPrint('表单验证通过');
              }
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}

/// 使用混入类创建验证文本框
class Example10ValidatedTextField extends StatefulWidget {
  const Example10ValidatedTextField({super.key});

  @override
  State<Example10ValidatedTextField> createState() =>
      _Example10ValidatedTextFieldState();
}

class _Example10ValidatedTextFieldState
    extends State<Example10ValidatedTextField>
    with TextFormFieldValidationMixin {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('验证示例')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: validatedTextField(
          controller: _controller,
          validator:
              FormValidator.validate('用户名', '').minLength(3).maxLength(20),
          decoration: const InputDecoration(
            labelText: '用户名',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ==================== 示例5：输入格式化器 ====================

/// 限制输入长度
class Example11LengthLimiting extends StatelessWidget {
  const Example11LengthLimiting({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: '最多输入20个字符',
        border: OutlineInputBorder(),
      ),
      inputFormatters: [
        InputFormatter.limitLength(20),
      ],
    );
  }
}

/// 仅允许数字输入（章节号）
class Example12DigitsOnly extends StatelessWidget {
  const Example12DigitsOnly({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: '章节号',
        border: OutlineInputBorder(),
        hintText: '请输入数字',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        InputFormatter.digitsOnly(),
      ],
    );
  }
}

/// 小数输入（带小数位限制）
class Example13DecimalInput extends StatelessWidget {
  const Example13DecimalInput({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: '进度（保留2位小数）',
        border: OutlineInputBorder(),
        hintText: '0.00',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        InputFormatter.decimalsOnly(decimalDigits: 2),
      ],
    );
  }
}

/// 手机号格式化（中国大陆）
class Example14PhoneFormatter extends StatelessWidget {
  const Example14PhoneFormatter({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: '手机号',
        border: OutlineInputBorder(),
        hintText: '138 1234 5678',
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        InputFormatter.phoneDigits(),
        InputFormatter.phoneFormatter(),
      ],
    );
  }
}

/// 日期格式化（YYYY-MM-DD）
class Example15DateFormatter extends StatelessWidget {
  const Example15DateFormatter({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: '发布日期',
        border: OutlineInputBorder(),
        hintText: '2024-01-15',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        InputFormatter.dateFormatter(),
      ],
    );
  }
}

/// 金额格式化（千位分隔符 + 2位小数）
class Example16CurrencyFormatter extends StatelessWidget {
  const Example16CurrencyFormatter({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: '金额',
        border: OutlineInputBorder(),
        hintText: '1,234.56',
        prefixText: '¥ ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        InputFormatter.currencyFormatter(),
      ],
    );
  }
}

/// 组合格式化器（URL输入）
class Example17CombinedFormatters extends StatelessWidget {
  const Example17CombinedFormatters({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: '小说URL',
        border: OutlineInputBorder(),
        hintText: 'https://example.com',
      ),
      keyboardType: TextInputType.url,
      inputFormatters: InputFormatter.combine([
        InputFormatter.urlCharacters(),
        InputFormatter.limitLength(500),
      ]),
    );
  }
}

/// 自定义格式化器（角色别名输入，禁止某些字符）
class Example18CustomFormatter extends StatelessWidget {
  const Example18CustomFormatter({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: '角色别名',
        border: OutlineInputBorder(),
        hintText: '用逗号分隔多个别名',
      ),
      inputFormatters: [
        InputFormatter.forbidChars(['<', '>', '"', "'", '\\']),
      ],
    );
  }
}

// ==================== 示例6：高级验证场景 ====================

/// 密码强度验证
void example19PasswordStrength() {
  final password = 'MyPass123';

  final result = FormValidator.validate('密码', password)
      .required()
      .password(
        minLength: 8,
        requireUppercase: true,
        requireLowercase: true,
        requireNumber: true,
        requireSpecialChar: false,
      )
      .result();

  if (!result.isValid) {
    debugPrint('密码强度不足: ${result.errorMessage}');
  }
}

/// 正则表达式验证（小说书名格式）
void example20RegexValidation() {
  final bookTitle = '《三体》';

  final result = FormValidator.validate('书名', bookTitle)
      .required()
      .regex(
        RegExp(r'^《.+》$'),
        '书名必须使用《》包裹',
      )
      .result();

  if (!result.isValid) {
    debugPrint('书名格式错误: ${result.errorMessage}');
  }
}

/// 自定义验证逻辑（章节标题唯一性）
void example21CustomValidation() {
  final existingTitles = ['第一章 开始', '第二章 发展'];
  final newTitle = '第一章 开始';

  final result =
      FormValidator.validate('章节标题', newTitle).required().custom((value) {
    if (existingTitles.contains(value)) {
      return '章节标题已存在';
    }
    return null;
  }).result();

  if (!result.isValid) {
    debugPrint('标题重复: ${result.errorMessage}');
  }
}

/// 链式验证组合
void example22ChainedValidation() {
  final userInput = 'user123';

  final result = FormValidator.validate('用户名', userInput)
      .required(message: '请输入用户名')
      .minLength(3, message: '用户名至少3个字符')
      .maxLength(20, message: '用户名最多20个字符')
      .regex(
        RegExp(r'^[a-zA-Z0-9_]+$'),
        '用户名只能包含字母、数字和下划线',
      )
      .result();

  debugPrint(result.isValid ? '用户名有效' : result.errorMessage);
}

// ==================== 示例7：实际应用场景 ====================

/// 小说搜索对话框验证
class NovelSearchDialogExample extends StatelessWidget {
  const NovelSearchDialogExample({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜索小说'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: '小说名称',
              border: OutlineInputBorder(),
            ),
            inputFormatters: [
              InputFormatter.limitLength(50),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: '作者（可选）',
              border: OutlineInputBorder(),
            ),
            inputFormatters: [
              InputFormatter.limitLength(30),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            // 执行搜索
            Navigator.of(context).pop();
          },
          child: const Text('搜索'),
        ),
      ],
    );
  }
}

/// 章节插入对话框验证
class InsertChapterDialogExample extends StatefulWidget {
  const InsertChapterDialogExample({super.key});

  @override
  State<InsertChapterDialogExample> createState() =>
      _InsertChapterDialogExampleState();
}

class _InsertChapterDialogExampleState
    extends State<InsertChapterDialogExample> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('插入自定义章节'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '章节标题 *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => QuickValidator.lengthRange(
                  value,
                  1,
                  100,
                  fieldName: '章节标题',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '章节内容 *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 10,
                maxLength: 10000,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '章节内容不能为空';
                  }
                  if (value.trim().length < 10) {
                    return '章节内容至少需要10个字符';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'title': _titleController.text.trim(),
                'content': _contentController.text.trim(),
              });
            }
          },
          child: const Text('插入'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}

// ==================== 使用总结 ====================

/// 使用总结：
///
/// 1. **基础验证**：
///    - 使用 `FormValidator.validate()` 创建验证器
///    - 使用链式调用添加多个验证规则
///    - 调用 `result()` 获取验证结果
///
/// 2. **快速验证**：
///    - 使用 `QuickValidator` 进行常见验证
///    - 适用于简单的 TextFormField validator
///
/// 3. **多字段验证**：
///    - 使用 `FormValidatorGroup` 管理多个字段
///    - 调用 `validateAll()` 一次性验证所有字段
///
/// 4. **输入格式化**：
///    - 使用 `InputFormatter` 限制和格式化输入
///    - 与验证器配合使用，提供更好的用户体验
///
/// 5. **TextFormField 集成**：
///    - 使用 `TextFormFieldValidationMixin` 混入类
///    - 或手动创建验证函数
///
/// 6. **自定义验证**：
///    - 使用 `custom()` 方法添加自定义逻辑
///    - 或实现 `ValidationRule` 接口创建可复用规则
///
/// 常见验证规则：
/// - `required()` - 非空验证
/// - `minLength()` / `maxLength()` - 长度验证
/// - `email()` - 邮箱验证
/// - `url()` - URL验证
/// - `number()` - 数字验证
/// - `range()` - 范围验证
/// - `unique()` - 防重复验证
/// - `password()` - 密码强度验证
/// - `regex()` - 正则表达式验证
///
/// 常见输入格式化器：
/// - `limitLength()` - 限制长度
/// - `digitsOnly()` - 仅数字
/// - `decimalsOnly()` - 仅小数
/// - `phoneFormatter()` - 手机号格式化
/// - `dateFormatter()` - 日期格式化
/// - `currencyFormatter()` - 金额格式化
void main() {
  debugPrint('表单验证工具使用示例');
  debugPrint('请参考上述示例代码了解详细用法');
}
