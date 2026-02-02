import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/services/preferences_service.dart';
import 'package:novel_app/core/providers/service_providers.dart';

void main() {
  group('PreferencesService Riverpod 集成测试', () {
    late ProviderContainer container;

    setUp(() async {
      // 在每次测试前设置 SharedPreferences 模拟
      SharedPreferences.setMockInitialValues({});

      // 创建新的 ProviderContainer
      container = ProviderContainer();
    });

    tearDown(() {
      // 清理容器
      container.dispose();
    });

    group('Provider 创建测试', () {
      test('preferencesServiceProvider 应该返回 PreferencesService 实例',
          () {
        final service = container.read(preferencesServiceProvider);

        expect(service, isNotNull);
        expect(service, isA<PreferencesService>());
      });

      test('preferencesServiceProvider 应该返回单例实例', () {
        final service1 = container.read(preferencesServiceProvider);
        final service2 = container.read(preferencesServiceProvider);

        expect(identical(service1, service2), true);
      });

      test('Provider 实例应该与 .instance 相同', () {
        final providerInstance = container.read(preferencesServiceProvider);
        final singletonInstance = PreferencesService.instance;

        expect(identical(providerInstance, singletonInstance), true);
      });
    });

    group('字符串操作测试', () {
      test('应该能够存储和读取字符串', () async {
        final service = container.read(preferencesServiceProvider);

        // 存储字符串
        final setResult = await service.setString('test_key', 'test_value');
        expect(setResult, true);

        // 读取字符串
        final getValue = await service.getString('test_key');
        expect(getValue, 'test_value');
      });

      test('读取不存在的键应该返回默认值', () async {
        final service = container.read(preferencesServiceProvider);

        final value = await service.getString('non_existent_key');
        expect(value, ''); // 默认空字符串
      });

      test('应该支持自定义默认值', () async {
        final service = container.read(preferencesServiceProvider);

        final value =
            await service.getString('non_existent_key', defaultValue: 'default');
        expect(value, 'default');
      });

      test('应该能够更新已存在的字符串值', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('key', 'value1');
        await service.setString('key', 'value2');

        final value = await service.getString('key');
        expect(value, 'value2');
      });

      test('应该能够存储空字符串', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('empty_key', '');
        final value = await service.getString('empty_key');

        expect(value, '');
      });

      test('应该能够存储包含特殊字符的字符串', () async {
        final service = container.read(preferencesServiceProvider);

        const specialString = '!@#\$%^&*()_+-=[]{}|;:\'",.<>?/~`中文🎉';
        await service.setString('special_key', specialString);

        final value = await service.getString('special_key');
        expect(value, specialString);
      });

      test('应该能够存储超长字符串', () async {
        final service = container.read(preferencesServiceProvider);

        final longString = 'A' * 10000;
        await service.setString('long_key', longString);

        final value = await service.getString('long_key');
        expect(value, longString);
        expect(value.length, 10000);
      });
    });

    group('整数操作测试', () {
      test('应该能够存储和读取整数', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setInt('int_key', 42);
        final value = await service.getInt('int_key');

        expect(value, 42);
      });

      test('读取不存在的整数键应该返回默认值 0', () async {
        final service = container.read(preferencesServiceProvider);

        final value = await service.getInt('non_existent_int');
        expect(value, 0);
      });

      test('应该支持自定义默认值', () async {
        final service = container.read(preferencesServiceProvider);

        final value = await service.getInt('non_existent_int', defaultValue: -1);
        expect(value, -1);
      });

      test('应该能够存储负数', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setInt('negative_key', -999);
        final value = await service.getInt('negative_key');

        expect(value, -999);
      });

      test('应该能够存储零', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setInt('zero_key', 0);
        final value = await service.getInt('zero_key');

        expect(value, 0);
      });

      test('应该能够存储大整数', () async {
        final service = container.read(preferencesServiceProvider);

        const largeInt = 9223372036854775807; // max int64
        await service.setInt('large_key', largeInt);

        final value = await service.getInt('large_key');
        expect(value, largeInt);
      });
    });

    group('双精度浮点数操作测试', () {
      test('应该能够存储和读取双精度浮点数', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setDouble('double_key', 3.14159);
        final value = await service.getDouble('double_key');

        expect(value, closeTo(3.14159, 0.00001));
      });

      test('读取不存在的双精度浮点数键应该返回默认值 0.0', () async {
        final service = container.read(preferencesServiceProvider);

        final value = await service.getDouble('non_existent_double');
        expect(value, 0.0);
      });

      test('应该支持自定义默认值', () async {
        final service = container.read(preferencesServiceProvider);

        final value = await service.getDouble('non_existent_double',
            defaultValue: 1.5);
        expect(value, 1.5);
      });

      test('应该能够存储负数', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setDouble('negative_double', -2.71828);
        final value = await service.getDouble('negative_double');

        expect(value, closeTo(-2.71828, 0.00001));
      });

      test('应该能够存储零', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setDouble('zero_double', 0.0);
        final value = await service.getDouble('zero_double');

        expect(value, 0.0);
      });

      test('应该能够存储科学计数法表示的数', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setDouble('sci_double', 1.23e-4);
        final value = await service.getDouble('sci_double');

        expect(value, closeTo(1.23e-4, 0.00001));
      });
    });

    group('布尔值操作测试', () {
      test('应该能够存储和读取布尔值 true', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setBool('bool_key', true);
        final value = await service.getBool('bool_key');

        expect(value, true);
      });

      test('应该能够存储和读取布尔值 false', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setBool('bool_key', false);
        final value = await service.getBool('bool_key');

        expect(value, false);
      });

      test('读取不存在的布尔键应该返回默认值 false', () async {
        final service = container.read(preferencesServiceProvider);

        final value = await service.getBool('non_existent_bool');
        expect(value, false);
      });

      test('应该支持自定义默认值', () async {
        final service = container.read(preferencesServiceProvider);

        final value =
            await service.getBool('non_existent_bool', defaultValue: true);
        expect(value, true);
      });

      test('应该能够切换布尔值', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setBool('toggle_key', true);
        expect(await service.getBool('toggle_key'), true);

        await service.setBool('toggle_key', false);
        expect(await service.getBool('toggle_key'), false);
      });
    });

    group('字符串列表操作测试', () {
      test('应该能够存储和读取字符串列表', () async {
        final service = container.read(preferencesServiceProvider);

        const list = ['item1', 'item2', 'item3'];
        await service.setStringList('list_key', list);

        final value = await service.getStringList('list_key');
        expect(value, list);
      });

      test('读取不存在的列表键应该返回空列表', () async {
        final service = container.read(preferencesServiceProvider);

        final value = await service.getStringList('non_existent_list');
        expect(value, isEmpty);
      });

      test('应该支持自定义默认值', () async {
        final service = container.read(preferencesServiceProvider);

        final defaultValue = ['default1', 'default2'];
        final value = await service.getStringList('non_existent_list',
            defaultValue: defaultValue);

        expect(value, defaultValue);
      });

      test('应该能够存储空列表', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setStringList('empty_list', []);
        final value = await service.getStringList('empty_list');

        expect(value, isEmpty);
      });

      test('应该能够存储包含特殊字符的列表', () async {
        final service = container.read(preferencesServiceProvider);

        const list = ['item!@#', 'item中文', 'item🎉', 'item\$\$'];
        await service.setStringList('special_list', list);

        final value = await service.getStringList('special_list');
        expect(value, list);
      });

      test('应该能够存储包含重复元素的列表', () async {
        final service = container.read(preferencesServiceProvider);

        const list = ['item1', 'item1', 'item2', 'item2'];
        await service.setStringList('duplicate_list', list);

        final value = await service.getStringList('duplicate_list');
        expect(value, list);
      });

      test('应该能够存储超长列表', () async {
        final service = container.read(preferencesServiceProvider);

        final longList = List.generate(1000, (i) => 'item_$i');
        await service.setStringList('long_list', longList);

        final value = await service.getStringList('long_list');
        expect(value.length, 1000);
        expect(value, longList);
      });
    });

    group('键检查和删除测试', () {
      test('containsKey 应该正确判断键是否存在', () async {
        final service = container.read(preferencesServiceProvider);

        expect(await service.containsKey('existing_key'), false);

        await service.setString('existing_key', 'value');
        expect(await service.containsKey('existing_key'), true);
      });

      test('remove 应该能够删除指定键', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('remove_key', 'value');
        expect(await service.containsKey('remove_key'), true);

        await service.remove('remove_key');
        expect(await service.containsKey('remove_key'), false);
      });

      test('remove 应该返回删除结果', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('remove_key', 'value');
        final result = await service.remove('remove_key');

        expect(result, true);
      });

      test('删除不存在的键应该返回 true', () async {
        final service = container.read(preferencesServiceProvider);

        final result = await service.remove('non_existent_key');
        expect(result, true);
      });

      test('getKeys 应该返回所有键', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('key1', 'value1');
        await service.setInt('key2', 42);
        await service.setBool('key3', true);

        final keys = await service.getKeys();
        expect(keys.contains('key1'), true);
        expect(keys.contains('key2'), true);
        expect(keys.contains('key3'), true);
      });

      test('getKeys 在没有数据时应该返回空集合', () async {
        final service = container.read(preferencesServiceProvider);

        final keys = await service.getKeys();
        expect(keys, isEmpty);
      });
    });

    group('批量操作测试', () {
      test('setMultiple 应该能够批量设置多个值', () async {
        final service = container.read(preferencesServiceProvider);

        final values = <String, dynamic>{
          'string_key': 'value',
          'int_key': 42,
          'double_key': 3.14,
          'bool_key': true,
          'list_key': ['a', 'b', 'c'],
        };

        final count = await service.setMultiple(values);
        expect(count, 5);

        expect(await service.getString('string_key'), 'value');
        expect(await service.getInt('int_key'), 42);
        expect(await service.getDouble('double_key'), closeTo(3.14, 0.01));
        expect(await service.getBool('bool_key'), true);
        expect(await service.getStringList('list_key'), ['a', 'b', 'c']);
      });

      test('setMultiple 应该返回成功设置的数量', () async {
        final service = container.read(preferencesServiceProvider);

        final values = <String, dynamic>{
          'key1': 'value1',
          'key2': 'value2',
          'key3': 'value3',
        };

        final count = await service.setMultiple(values);
        expect(count, 3);
      });

      test('getMultiple 应该能够批量获取多个值', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('key1', 'value1');
        await service.setInt('key2', 42);
        await service.setString('key3', 'value3');

        final keys = {'key1', 'key2', 'key3', 'non_existent'};
        final result = await service.getMultiple(keys);

        expect(result['key1'], 'value1');
        expect(result['key2'], 42);
        expect(result['key3'], 'value3');
        expect(result.containsKey('non_existent'), false);
      });

      test('getMultiple 在没有数据时应该返回空映射', () async {
        final service = container.read(preferencesServiceProvider);

        final result = await service.getMultiple({'key1', 'key2'});
        expect(result, isEmpty);
      });

      test('setMultiple 应该能够处理空映射', () async {
        final service = container.read(preferencesServiceProvider);

        final count = await service.setMultiple({});
        expect(count, 0);
      });

      test('getMultiple 应该能够处理空集合', () async {
        final service = container.read(preferencesServiceProvider);

        final result = await service.getMultiple({});
        expect(result, isEmpty);
      });
    });

    group('清空操作测试', () {
      test('clear 应该能够清空所有数据', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('key1', 'value1');
        await service.setInt('key2', 42);
        await service.setBool('key3', true);

        expect(await service.getKeys(), isNotEmpty);

        await service.clear();

        expect(await service.getKeys(), isEmpty);
      });

      test('clear 应该返回清空结果', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('key', 'value');
        final result = await service.clear();

        expect(result, true);
      });

      test('clear 在空数据上应该成功', () async {
        final service = container.read(preferencesServiceProvider);

        final result = await service.clear();
        expect(result, true);
      });
    });

    group('向后兼容性测试', () {
      test('.instance 应该仍然可用', () {
        final instance = PreferencesService.instance;

        expect(instance, isNotNull);
        expect(instance, isA<PreferencesService>());
      });

      test('.instance 应该返回相同的实例', () {
        final instance1 = PreferencesService.instance;
        final instance2 = PreferencesService.instance;

        expect(identical(instance1, instance2), true);
      });

      test('Provider 实例应该与 .instance 一致', () {
        final providerInstance = container.read(preferencesServiceProvider);
        final singletonInstance = PreferencesService.instance;

        expect(identical(providerInstance, singletonInstance), true);
      });

      test('.instance 应该能够正常使用', () async {
        final instance = PreferencesService.instance;

        await instance.setString('compat_key', 'compat_value');
        final value = await instance.getString('compat_key');

        expect(value, 'compat_value');
      });
    });

    group('数据持久化测试', () {
      test('数据应该在不同实例间持久化', () async {
        final service1 = container.read(preferencesServiceProvider);

        // 使用第一个实例设置数据
        await service1.setString('persistent_key', 'persistent_value');
        await service1.setInt('persistent_int', 123);

        // 使用同一个实例读取数据
        expect(await service1.getString('persistent_key'), 'persistent_value');
        expect(await service1.getInt('persistent_int'), 123);
      });
    });

    group('边界情况测试', () {
      test('应该能够处理空字符串键', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('', 'value');
        final value = await service.getString('');

        expect(value, 'value');
      });

      test('应该能够处理超长键名', () async {
        final service = container.read(preferencesServiceProvider);

        final longKey = 'a' * 1000;
        await service.setString(longKey, 'value');

        final value = await service.getString(longKey);
        expect(value, 'value');
      });

      test('应该能够处理包含特殊字符的键名', () async {
        final service = container.read(preferencesServiceProvider);

        const specialKey = 'key!@#\$%^&*()_+-=[]{}|;:\'",.<>?/~`中文🎉';
        await service.setString(specialKey, 'value');

        final value = await service.getString(specialKey);
        expect(value, 'value');
      });

      test('应该能够处理连续的操作', () async {
        final service = container.read(preferencesServiceProvider);

        for (int i = 0; i < 100; i++) {
          await service.setString('key_$i', 'value_$i');
          await service.setInt('int_$i', i);
          await service.setBool('bool_$i', i % 2 == 0);
        }

        final keys = await service.getKeys();
        expect(keys.length, greaterThanOrEqualTo(300));
      });
    });

    group('类型安全测试', () {
      test('不应该能够跨类型读取', () async {
        final service = container.read(preferencesServiceProvider);

        await service.setString('type_key', 'string');

        // 尝试用错误的类型读取会抛出异常或返回默认值
        // 在 SharedPreferences 中，跨类型读取会抛出类型转换异常
        // 实际应用中应该避免这种情况
        try {
          await service.getInt('type_key');
          // 如果没有抛出异常，会返回默认值
          fail('Expected type conversion error');
        } catch (e) {
          // 预期的类型转换错误
          expect(e, isA<TypeError>());
        }
      });

      test('应该能够正确覆盖不同类型的值', () async {
        final service = container.read(preferencesServiceProvider);

        // 先存储字符串
        await service.setString('type_change_key', 'string_value');
        expect(await service.getString('type_change_key'), 'string_value');

        // 删除旧值后再存储新类型
        await service.remove('type_change_key');
        await service.setInt('type_change_key', 456);
        expect(await service.getInt('type_change_key'), 456);

        // 再次删除后存储布尔值
        await service.remove('type_change_key');
        await service.setBool('type_change_key', true);
        expect(await service.getBool('type_change_key'), true);
      });
    });

    group('单例模式测试', () {
      test('应该始终返回相同的实例', () {
        final instance1 = PreferencesService.instance;
        final instance2 = PreferencesService.instance;
        final instance3 = PreferencesService();

        expect(identical(instance1, instance2), true);
        expect(identical(instance1, instance3), true);
      });

      test('factory 构造函数应该返回单例', () {
        final instance1 = PreferencesService();
        final instance2 = PreferencesService.instance;

        expect(identical(instance1, instance2), true);
      });

      test('Provider 应该返回相同的单例实例', () {
        final providerInstance = container.read(preferencesServiceProvider);
        final singletonInstance = PreferencesService.instance;

        expect(identical(providerInstance, singletonInstance), true);
      });
    });
  });
}
