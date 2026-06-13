/// Deque 双端队列单元测试
///
/// 验证双端队列的所有基本操作，包括边界条件和错误处理。
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/utils/deque_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/deque.dart';

void main() {
  group('Deque', () {
    late Deque<int> deque;

    setUp(() {
      deque = Deque<int>();
    });

    group('初始状态', () {
      test('应为空', () {
        expect(deque.isEmpty, isTrue);
        expect(deque.isNotEmpty, isFalse);
      });

      test('长度应为 0', () {
        expect(deque.length, 0);
      });

      test('toString 应返回空队列表示', () {
        expect(deque.toString(), 'Deque[]');
      });
    });

    group('addLast', () {
      test('应在尾部添加元素', () {
        deque.addLast(1);
        deque.addLast(2);

        expect(deque.length, 2);
        expect(deque.first, 1);
        expect(deque.last, 2);
      });

      test('单个元素时 first 和 last 应相同', () {
        deque.addLast(42);

        expect(deque.first, 42);
        expect(deque.last, 42);
      });
    });

    group('addFirst', () {
      test('应在头部添加元素', () {
        deque.addFirst(1);
        deque.addFirst(0);

        expect(deque.length, 2);
        expect(deque.first, 0);
        expect(deque.last, 1);
      });
    });

    group('removeFirst', () {
      test('应移除并返回头部元素', () {
        deque.addLast(1);
        deque.addLast(2);

        final first = deque.removeFirst();
        expect(first, 1);
        expect(deque.length, 1);
        expect(deque.first, 2);
      });

      test('空队列应抛出 StateError', () {
        expect(() => deque.removeFirst(), throwsA(isA<StateError>()));
      });
    });

    group('removeLast', () {
      test('应移除并返回尾部元素', () {
        deque.addLast(1);
        deque.addLast(2);

        final last = deque.removeLast();
        expect(last, 2);
        expect(deque.length, 1);
        expect(deque.last, 1);
      });

      test('空队列应抛出 StateError', () {
        expect(() => deque.removeLast(), throwsA(isA<StateError>()));
      });
    });

    group('first getter', () {
      test('空队列应抛出 StateError', () {
        expect(() => deque.first, throwsA(isA<StateError>()));
      });
    });

    group('last getter', () {
      test('空队列应抛出 StateError', () {
        expect(() => deque.last, throwsA(isA<StateError>()));
      });
    });

    group('clear', () {
      test('应清空所有元素', () {
        deque.addLast(1);
        deque.addLast(2);
        deque.addLast(3);

        deque.clear();

        expect(deque.isEmpty, isTrue);
        expect(deque.length, 0);
      });

      test('清空后再次添加应正常', () {
        deque.addLast(1);
        deque.clear();
        deque.addLast(2);

        expect(deque.length, 1);
        expect(deque.first, 2);
      });
    });

    group('iterable', () {
      test('应提供可迭代对象用于遍历', () {
        deque.addLast(1);
        deque.addLast(2);
        deque.addLast(3);

        final result = deque.iterable.toList();
        expect(result, [1, 2, 3]);
      });
    });

    group('toString', () {
      test('应正确表示非空队列', () {
        deque.addLast(1);
        deque.addLast(2);

        expect(deque.toString(), 'Deque[1, 2]');
      });
    });

    group('混合操作', () {
      test('addFirst 和 addLast 混合使用', () {
        deque.addLast(2);
        deque.addFirst(1);
        deque.addLast(3);

        expect(deque.first, 1);
        expect(deque.last, 3);
        expect(deque.iterable.toList(), [1, 2, 3]);
      });

      test('removeFirst 和 removeLast 交替', () {
        deque.addLast(1);
        deque.addLast(2);
        deque.addLast(3);
        deque.addLast(4);

        deque.removeFirst(); // 移除 1
        deque.removeLast(); // 移除 4

        expect(deque.iterable.toList(), [2, 3]);
      });
    });

    group('泛型类型', () {
      test('应支持 String 类型', () {
        final strDeque = Deque<String>();
        strDeque.addLast('hello');
        strDeque.addLast('world');

        expect(strDeque.first, 'hello');
        expect(strDeque.last, 'world');
      });

      test('应支持自定义类型', () {
        final objDeque = Deque<_TestItem>();
        objDeque.addLast(const _TestItem(1));
        objDeque.addLast(const _TestItem(2));

        expect(objDeque.first.value, 1);
      });
    });
  });
}

class _TestItem {
  final int value;
  const _TestItem(this.value);
}
