# 表单验证工具使用指南

本项目提供了统一的表单验证工具类，用于简化Flutter应用中的表单验证逻辑。

## 文件清单

| 文件 | 大小 | 说明 |
|------|------|------|
| `lib/utils/validation_result.dart` | 17KB | 验证结果封装类和内置验证规则 |
| `lib/utils/form_validator.dart` | 15KB | 链式表单验证器 |
| `lib/utils/input_formatter.dart` | 19KB | 输入格式化器 |
| `lib/utils/form_validation_examples.dart` | 20KB | 完整使用示例 |

## 核心特性

### 1. 链式API
```dart
final result = FormValidator.validate('用户名', 'John')
    .required()
    .minLength(3)
    .maxLength(20)
    .result();

if (result.isValid) {
  print('验证通过');
}
```

### 2. 自定义错误消息
```dart
final result = FormValidator.validate('角色名称', '张三')
    .required(message: '请输入角色名称')
    .unique(existingNames, message: '该角色名称已存在')
    .result();
```

### 3. 多规则组合
```dart
// 邮箱验证
final emailResult = FormValidator.validate('邮箱', 'user@example.com')
    .required()
    .email()
    .result();

// URL验证
final urlResult = FormValidator.validate('小说URL', 'https://example.com')
    .required()
    .url()
    .result();

// 数字范围验证
final numberResult = FormValidator.validate('章节号', '100')
    .required()
    .number()
    .range(min: 1, max: 9999)
    .result();
```

### 4. TextFormField集成
```dart
TextFormField(
  decoration: const InputDecoration(labelText: '邮箱'),
  validator: (value) => QuickValidator.email(value),
)
```

## 内置验证规则

### 基础验证
- `required()` - 非空验证
- `minLength(int)` - 最小长度
- `maxLength(int)` - 最大长度
- `lengthRange(int min, int max)` - 长度范围

### 格式验证
- `email()` - 邮箱格式
- `url()` - URL格式
- `phone()` - 手机号（中国大陆）
- `idCard()` - 身份证号（中国大陆）
- `chineseOnly()` - 仅中文字符

### 数值验证
- `number()` - 数字格式
- `range({min, max})` - 数值范围
- `decimalsOnly(int)` - 小数位数限制

### 高级验证
- `unique(List<String>)` - 防重复验证
- `password()` - 密码强度验证
- `dateFormat(String)` - 日期格式验证
- `regex(RegExp, String)` - 正则表达式验证
- `custom(Function)` - 自定义验证逻辑

## 输入格式化器

### 基础格式化
```dart
// 限制输入长度
InputFormatter.limitLength(20)

// 仅数字
InputFormatter.digitsOnly()

// 仅小数（2位）
InputFormatter.decimalsOnly(decimalDigits: 2)
```

### 自动格式化
```dart
// 手机号（138 1234 5678）
InputFormatter.phoneFormatter()

// 日期（YYYY-MM-DD）
InputFormatter.dateFormatter()

// 金额（千位分隔符 + 2位小数）
InputFormatter.currencyFormatter()

// 身份证号（123456 1990 01 01 1234）
InputFormatter.idCardFormatter()
```

### 字符过滤
```dart
// 仅字母
InputFormatter.lettersOnly()

// 仅中文
InputFormatter.chineseOnly()

// 仅字母数字
InputFormatter.alphanumeric()

// URL字符
InputFormatter.urlCharacters()

// 禁止特定字符
InputFormatter.forbidChars(['<', '>', '"'])
```

## 实际应用场景

### 场景1：角色名称验证（防重复）
```dart
// 参考：character_input_dialog.dart
final existingCharacters = ['张三', '李四', '王五'];
final newName = '赵六';

final result = FormValidator.validate('角色名称', newName)
    .required()
    .minLength(2)
    .maxLength(20)
    .unique(existingCharacters)
    .result();

if (!result.isValid) {
  ToastUtils.showError(result.errorMessage);
}
```

### 场景2：沉浸体验配置验证
```dart
// 参考：immersive_setup_dialog.dart
final validatorGroup = FormValidatorGroup();

// 验证用户要求
validatorGroup.field('体验要求', userRequirement)
    .required()
    .minLength(10, message: '描述至少需要10个字符');

// 执行所有验证
final result = validatorGroup.validateAll();
if (!result.isValid) {
  ToastUtils.showError(result.errorMessage);
}
```

### 场景3：章节插入对话框
```dart
// 参考：insert_chapter_screen.dart
TextFormField(
  decoration: const InputDecoration(labelText: '章节标题 *'),
  validator: (value) => QuickValidator.lengthRange(
    value,
    1,
    100,
    fieldName: '章节标题',
  ),
)
```

## 快速参考

### QuickValidator快速验证方法
```dart
QuickValidator.required(value, message: '不能为空')
QuickValidator.email(value, message: '邮箱格式错误')
QuickValidator.url(value, message: 'URL格式错误')
QuickValidator.number(value, message: '请输入数字')
QuickValidator.phone(value, message: '手机号格式错误')
QuickValidator.idCard(value, message: '身份证号格式错误')
QuickValidator.lengthRange(value, min, max, fieldName: '字段名')
QuickValidator.characterName(value, existingNames, message: '名称已存在')
```

### FormValidatorGroup多字段验证
```dart
final group = FormValidatorGroup();
group.field('字段1', value1).required().minLength(3);
group.field('字段2', value2).required().email();

// 验证所有字段
final result = group.validateAll();
if (result.isValid) {
  print('所有字段验证通过');
} else {
  print('验证失败: ${result.getFirstError()}');
}

// 获取所有错误
final errors = group.getAllErrors();
errors.forEach((field, error) {
  print('$field: $error');
});
```

## 迁移现有代码

### 迁移前（character_input_dialog.dart）
```dart
final name = _nameController.text.trim();
if (name.isEmpty) {
  ToastUtils.showError('请输入角色正式名称');
  return;
}
```

### 迁移后
```dart
final result = FormValidator.validate('角色正式名称', _nameController.text)
    .required()
    .result();

if (!result.isValid) {
  ToastUtils.showError(result.errorMessage);
  return;
}
```

## 最佳实践

1. **使用字段名**：始终提供有意义的字段名，便于错误消息显示
2. **链式调用**：利用链式API组合多个验证规则
3. **自定义消息**：为关键验证提供自定义错误消息
4. **输入格式化**：配合InputFormatter限制用户输入，减少验证错误
5. **多字段验证**：使用FormValidatorGroup管理复杂表单

## 完整示例

请参考 `lib/utils/form_validation_examples.dart` 查看详细的使用示例，包含22个实际应用场景。
