/// FormValidator 表单验证器单元测试
///
/// 验证所有 14 个验证规则 + FormValidatorGroup + QuickValidator：
/// - RequiredRule / LengthRule / UrlRule / NumberRule
/// - EmailRule / RangeRule / RegexRule / CustomRule
/// - UniqueRule / PasswordStrengthRule / ChineseOnlyRule
/// - ChinesePhoneRule / ChineseIdCardRule / DateFormatRule
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/utils/form_validator_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/form_validator.dart';
import 'package:novel_app/utils/validation_result.dart';

void main() {
  group('ValidationResult', () {
    group('success', () {
      test('应创建成功结果', () {
        final result = ValidationResult.success();
        expect(result.isValid, isTrue);
        expect(result.errorMessage, isNull);
        expect(result.field, isNull);
      });
    });

    group('failure', () {
      test('应创建失败结果', () {
        final result = ValidationResult.failure('错误消息', field: 'username');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, '错误消息');
        expect(result.field, 'username');
      });

      test('应支持 details 参数', () {
        final result = ValidationResult.failure(
          '错误',
          field: 'f',
          details: {'code': 1},
        );
        expect(result.details, {'code': 1});
      });
    });

    group('merge', () {
      test('全部成功应返回成功', () {
        final results = [
          ValidationResult.success(),
          ValidationResult.success(),
        ];
        expect(ValidationResult.merge(results).isValid, isTrue);
      });

      test('任一失败应返回第一个失败', () {
        final results = [
          ValidationResult.success(),
          ValidationResult.failure('第一个错误'),
          ValidationResult.failure('第二个错误'),
        ];
        final merged = ValidationResult.merge(results);
        expect(merged.isValid, isFalse);
        expect(merged.errorMessage, '第一个错误');
      });

      test('空列表应返回成功', () {
        expect(ValidationResult.merge([]).isValid, isTrue);
      });
    });

    group('fullErrorMessage', () {
      test('带字段名应使用 字段: 消息 格式', () {
        final result =
            ValidationResult.failure('不能为空', field: 'username');
        expect(result.fullErrorMessage, 'username: 不能为空');
      });

      test('无字段名应只返回消息', () {
        final result = ValidationResult.failure('不能为空');
        expect(result.fullErrorMessage, '不能为空');
      });
    });

    group('==', () {
      test('相同的成功结果应相等', () {
        expect(ValidationResult.success() == ValidationResult.success(),
            isTrue);
      });

      test('相同的失败结果应相等', () {
        final a = ValidationResult.failure('err', field: 'f');
        final b = ValidationResult.failure('err', field: 'f');
        expect(a == b, isTrue);
      });
    });
  });

  group('FormValidator', () {
    group('required', () {
      test('非空字符串应通过', () {
        final result = FormValidator.validate('username', 'value')
            .required()
            .result();
        expect(result.isValid, isTrue);
      });

      test('空字符串应失败', () {
        final result = FormValidator.validate('username', '')
            .required()
            .result();
        expect(result.isValid, isFalse);
      });

      test('纯空白应失败（默认）', () {
        final result = FormValidator.validate('username', '   ')
            .required()
            .result();
        expect(result.isValid, isFalse);
      });

      test('allowWhitespace=true 时纯空白应通过', () {
        final result = FormValidator.validate('username', '   ')
            .required(allowWhitespace: true)
            .result();
        expect(result.isValid, isTrue);
      });

      test('null 应失败', () {
        final result = FormValidator.validate('username', null)
            .required()
            .result();
        expect(result.isValid, isFalse);
      });
    });

    group('minLength / maxLength / lengthRange', () {
      test('minLength 不足应失败', () {
        final result = FormValidator.validate('name', 'ab')
            .minLength(3)
            .result();
        expect(result.isValid, isFalse);
      });

      test('minLength 满足应通过', () {
        final result = FormValidator.validate('name', 'abc')
            .minLength(3)
            .result();
        expect(result.isValid, isTrue);
      });

      test('maxLength 超出应失败', () {
        final result = FormValidator.validate('name', 'abcdef')
            .maxLength(5)
            .result();
        expect(result.isValid, isFalse);
      });

      test('lengthRange 应同时检查最小和最大', () {
        expect(
            FormValidator.validate('f', 'ab').lengthRange(3, 5).result().isValid,
            isFalse);
        expect(
            FormValidator.validate('f', 'abc').lengthRange(3, 5).result().isValid,
            isTrue);
        expect(
            FormValidator.validate('f', 'abcdef').lengthRange(3, 5).result().isValid,
            isFalse);
      });
    });

    group('url', () {
      test('有效 https URL 应通过', () {
        final result = FormValidator.validate('url', 'https://example.com')
            .url()
            .result();
        expect(result.isValid, isTrue);
      });

      test('有效 http URL 应通过', () {
        final result = FormValidator.validate('url', 'http://example.com')
            .url()
            .result();
        expect(result.isValid, isTrue);
      });

      test('无协议的 URL 应失败（默认）', () {
        final result = FormValidator.validate('url', 'example.com')
            .url()
            .result();
        expect(result.isValid, isFalse);
      });

      test('requireProtocol=false 时无协议应通过', () {
        final result = FormValidator.validate('url', 'example.com')
            .url(requireProtocol: false)
            .result();
        expect(result.isValid, isTrue);
      });

      test('无效 URL 应失败', () {
        final result = FormValidator.validate('url', 'not a url')
            .url()
            .result();
        expect(result.isValid, isFalse);
      });
    });

    group('number', () {
      test('整数应通过', () {
        final result = FormValidator.validate('age', '25')
            .number()
            .result();
        expect(result.isValid, isTrue);
      });

      test('小数应通过（默认）', () {
        final result = FormValidator.validate('price', '3.14')
            .number()
            .result();
        expect(result.isValid, isTrue);
      });

      test('allowDecimal=false 时小数应失败', () {
        final result = FormValidator.validate('age', '3.14')
            .number(allowDecimal: false)
            .result();
        expect(result.isValid, isFalse);
      });

      test('allowNegative=true 时负数应通过', () {
        final result = FormValidator.validate('temp', '-5')
            .number(allowNegative: true)
            .result();
        expect(result.isValid, isTrue);
      });

      test('非数字应失败', () {
        final result = FormValidator.validate('n', 'abc')
            .number()
            .result();
        expect(result.isValid, isFalse);
      });
    });

    group('range', () {
      test('范围内应通过', () {
        final result = FormValidator.validate('age', '25')
            .range(min: 18, max: 100)
            .result();
        expect(result.isValid, isTrue);
      });

      test('小于最小值应失败', () {
        final result = FormValidator.validate('age', '10')
            .range(min: 18, max: 100)
            .result();
        expect(result.isValid, isFalse);
      });

      test('大于最大值应失败', () {
        final result = FormValidator.validate('age', '200')
            .range(min: 18, max: 100)
            .result();
        expect(result.isValid, isFalse);
      });

      test('只设置 min 时应只检查下限', () {
        expect(
            FormValidator.validate('a', '1').range(min: 0).result().isValid,
            isTrue);
        expect(
            FormValidator.validate('a', '-1').range(min: 0).result().isValid,
            isFalse);
      });
    });

    group('email', () {
      test('有效邮箱应通过', () {
        final result = FormValidator.validate('email', 'test@example.com')
            .email()
            .result();
        expect(result.isValid, isTrue);
      });

      test('无效邮箱应失败', () {
        final result = FormValidator.validate('email', 'invalid')
            .email()
            .result();
        expect(result.isValid, isFalse);
      });
    });

    group('regex', () {
      test('匹配应通过', () {
        final result = FormValidator.validate('code', 'ABC123')
            .regex(RegExp(r'^[A-Z]{3}\d{3}$'), '格式错误')
            .result();
        expect(result.isValid, isTrue);
      });

      test('不匹配应失败', () {
        final result = FormValidator.validate('code', 'abc')
            .regex(RegExp(r'^[A-Z]{3}$'), '格式错误')
            .result();
        expect(result.isValid, isFalse);
        expect(result.errorMessage, '格式错误');
      });
    });

    group('custom', () {
      test('自定义验证通过时应通过', () {
        final result = FormValidator.validate('even', '4')
            .custom((v) => int.parse(v) % 2 == 0 ? null : '必须是偶数')
            .result();
        expect(result.isValid, isTrue);
      });

      test('自定义验证失败时应失败', () {
        final result = FormValidator.validate('even', '3')
            .custom((v) => int.parse(v) % 2 == 0 ? null : '必须是偶数')
            .result();
        expect(result.isValid, isFalse);
        expect(result.errorMessage, '必须是偶数');
      });
    });

    group('unique', () {
      test('不在 existing 列表中应通过', () {
        final result = FormValidator.validate('name', 'newName')
            .unique(['existing1', 'existing2'])
            .result();
        expect(result.isValid, isTrue);
      });

      test('在 existing 列表中应失败', () {
        final result = FormValidator.validate('name', 'existing1')
            .unique(['existing1', 'existing2'])
            .result();
        expect(result.isValid, isFalse);
      });

      test('caseSensitive=false 应忽略大小写', () {
        final result = FormValidator.validate('name', 'EXISTING1')
            .unique(['existing1'], caseSensitive: false)
            .result();
        expect(result.isValid, isFalse);
      });
    });

    group('password', () {
      test('所有规则满足应通过', () {
        final result = FormValidator.validate('pwd', 'Aa1!aaaa')
            .password()
            .result();
        expect(result.isValid, isTrue);
      });

      test('长度不足应失败', () {
        final result =
            FormValidator.validate('pwd', 'Aa1!').password().result();
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('长度'));
      });

      test('缺少大写字母应失败', () {
        final result = FormValidator.validate('pwd', 'aa1!aaaa')
            .password()
            .result();
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('大写'));
      });

      test('缺少数字应失败', () {
        final result = FormValidator.validate('pwd', 'Aa!aaaaa')
            .password()
            .result();
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('数字'));
      });
    });

    group('chineseOnly', () {
      test('纯中文应通过', () {
        final result = FormValidator.validate('name', '张三李四')
            .chineseOnly()
            .result();
        expect(result.isValid, isTrue);
      });

      test('包含英文应失败', () {
        final result = FormValidator.validate('name', '张三abc')
            .chineseOnly()
            .result();
        expect(result.isValid, isFalse);
      });
    });

    group('phone', () {
      test('有效手机号应通过', () {
        final result = FormValidator.validate('phone', '13800138000')
            .phone()
            .result();
        expect(result.isValid, isTrue);
      });

      test('无效手机号应失败', () {
        final result = FormValidator.validate('phone', '12345')
            .phone()
            .result();
        expect(result.isValid, isFalse);
      });
    });

    group('idCard', () {
      test('15 位身份证号应通过', () {
        final result = FormValidator.validate('id', '123456789012345')
            .idCard()
            .result();
        expect(result.isValid, isTrue);
      });

      test('18 位有效身份证号应通过（正确的校验码）', () {
        // 使用真实的校验码计算: 110101199003072816
        // factors: [7,9,10,5,8,4,2,1,6,3,7,9,10,5,8,4,2]
        // sum = 1*7 + 1*9 + 0*10 + 1*5 + 0*8 + 1*4 + 1*2 + 9*1 + 9*6 + 0*3 + 0*7 + 3*9 + 0*10 + 7*5 + 2*8 + 8*4 + 1*2
        //     = 7+9+0+5+0+4+2+9+54+0+0+27+0+35+16+32+2 = 202
        // checkCode = checkCodes[202 % 11] = checkCodes[4] = '8'
        final result = FormValidator.validate('id', '110101199003072818')
            .idCard()
            .result();
        expect(result.isValid, isTrue);
      });

      test('18 位身份证号校验码错误应失败', () {
        final result = FormValidator.validate('id', '110101199003072811')
            .idCard()
            .result();
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('校验码'));
      });
    });

    group('dateFormat', () {
      test('正确格式 yyyy-MM-dd 应通过', () {
        final result = FormValidator.validate('date', '2024-01-15')
            .dateFormat('yyyy-MM-dd')
            .result();
        expect(result.isValid, isTrue);
      });

      test('正确格式 yyyy/MM/dd 应通过', () {
        final result = FormValidator.validate('date', '2024/01/15')
            .dateFormat('yyyy/MM/dd')
            .result();
        expect(result.isValid, isTrue);
      });

      test('月份超出范围应失败', () {
        // 13 不匹配 (0[1-9]|1[0-2]) 正则
        final result = FormValidator.validate('date', '2024-13-01')
            .dateFormat('yyyy-MM-dd')
            .result();
        expect(result.isValid, isFalse);
      });

      test('日期超出范围应失败', () {
        // 32 不匹配 (0[1-9]|[12]\d|3[01]) 正则
        final result = FormValidator.validate('date', '2024-01-32')
            .dateFormat('yyyy-MM-dd')
            .result();
        expect(result.isValid, isFalse);
      });

      test('错误格式应失败', () {
        // 使用文本字符分隔符，不在 [-/\.] 范围内
        final result = FormValidator.validate('date', '2024年01月15')
            .dateFormat('yyyy-MM-dd')
            .result();
        expect(result.isValid, isFalse);
      });

      test('无效日期应失败（如 2 月 30 日）', () {
        final result = FormValidator.validate('date', '2024-02-30')
            .dateFormat('yyyy-MM-dd')
            .result();
        expect(result.isValid, isFalse);
      });
    });

    group('isValid getter', () {
      test('应返回验证结果', () {
        final validator = FormValidator.validate('f', 'value').required();
        expect(validator.isValid, isTrue);

        final invalid = FormValidator.validate('f', '').required();
        expect(invalid.isValid, isFalse);
      });
    });

    group('errorMessage getter', () {
      test('应返回错误消息', () {
        final validator = FormValidator.validate('f', '').required();
        expect(validator.errorMessage, isNotNull);
        expect(validator.errorMessage, contains('不能为空'));
      });
    });

    group('reset', () {
      test('应清除已验证状态以重新验证', () {
        final validator = FormValidator.validate('f', '').required();
        expect(validator.isValid, isFalse);

        // 外部修改 state 不可能，但可以重置后看到 validator 可重用
        validator.reset();

        // 重新调用 isValid 应再次执行验证
        expect(validator.isValid, isFalse);
      });
    });

    group('链式调用', () {
      test('应支持多个规则组合', () {
        final result = FormValidator.validate('username', 'abc')
            .required()
            .minLength(3)
            .maxLength(20)
            .result();

        expect(result.isValid, isTrue);
      });

      test('任一规则失败应短路返回', () {
        final result = FormValidator.validate('f', 'a')
            .required()
            .minLength(3) // 失败
            .maxLength(20)
            .result();

        expect(result.isValid, isFalse);
      });
    });
  });

  group('FormValidatorGroup', () {
    test('应验证多字段', () {
      final group = FormValidatorGroup();
      group.field('username', 'john').required().minLength(3);
      group.field('email', 'john@example.com').required().email();
      group.field('age', '25').required().number();

      final result = group.validateAll();

      expect(result.isValid, isTrue);
      expect(group.isAllValid, isTrue);
    });

    test('任一字段失败应返回失败（stopOnFirstError=true）', () {
      final group = FormValidatorGroup();
      group.field('username', 'a').required().minLength(3);
      group.field('email', 'invalid').required().email();

      final result = group.validateAll();

      expect(result.isValid, isFalse);
      // 应返回第一个错误
      expect(result.errorMessage, contains('长度'));
    });

    test('应返回所有错误', () {
      final group = FormValidatorGroup();
      group.field('username', '').required();
      group.field('email', 'invalid').email();

      final errors = group.getAllErrors();

      expect(errors.containsKey('username'), isTrue);
      expect(errors.containsKey('email'), isTrue);
    });

    test('getFirstError 应返回第一个错误', () {
      final group = FormValidatorGroup();
      group.field('username', '').required();
      group.field('email', 'invalid').email();

      final firstError = group.getFirstError();

      expect(firstError, isNotNull);
      expect(firstError, contains('username'));
    });

    test('resetAll 应重置所有验证器', () {
      final group = FormValidatorGroup();
      group.field('f', '').required();
      expect(group.isAllValid, isFalse);

      group.resetAll();

      // 重新调用 isAllValid 应再次验证
      expect(group.isAllValid, isFalse);
    });
  });

  group('QuickValidator', () {
    group('required', () {
      test('空值应返回错误消息', () {
        expect(QuickValidator.required(''), isNotNull);
      });

      test('非空值应返回 null', () {
        expect(QuickValidator.required('value'), isNull);
      });
    });

    group('email', () {
      test('有效邮箱应返回 null', () {
        expect(QuickValidator.email('test@example.com'), isNull);
      });

      test('无效邮箱应返回错误消息', () {
        expect(QuickValidator.email('invalid'), isNotNull);
      });
    });

    group('url', () {
      test('有效 URL 应返回 null', () {
        expect(QuickValidator.url('https://example.com'), isNull);
      });

      test('无效 URL 应返回错误消息', () {
        expect(QuickValidator.url('not-a-url'), isNotNull);
      });
    });

    group('phone', () {
      test('有效手机号应返回 null', () {
        expect(QuickValidator.phone('13800138000'), isNull);
      });

      test('无效手机号应返回错误消息', () {
        expect(QuickValidator.phone('12345'), isNotNull);
      });
    });

    group('characterName', () {
      test('有效角色名应返回 null', () {
        expect(QuickValidator.characterName('张三', []), isNull);
      });

      test('重复角色名应返回错误消息', () {
        expect(QuickValidator.characterName('张三', ['张三']), isNotNull);
      });

      test('长度过短应返回错误消息', () {
        expect(QuickValidator.characterName('甲', []), isNotNull);
      });

      test('长度过长应返回错误消息', () {
        final longName = 'a' * 25;
        expect(QuickValidator.characterName(longName, []), isNotNull);
      });
    });

    group('lengthRange', () {
      test('范围内应返回 null', () {
        expect(QuickValidator.lengthRange('abc', 3, 5), isNull);
      });

      test('超出范围应返回错误消息', () {
        expect(QuickValidator.lengthRange('ab', 3, 5), isNotNull);
      });
    });
  });
}
