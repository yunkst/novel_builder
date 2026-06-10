import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/models/segment.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';

void main() {
  group('Segment', () {
    test('StringSegment toObject returns string', () {
      const segment = StringSegment(value: 'hello');
      expect(segment.toObject(), 'hello');
      expect(segment.text, 'hello');
    });

    test('ObjectSegment toObject returns map', () {
      final segment = ObjectSegment(value: {'name': 'Alice', 'age': 25});
      expect(segment.toObject(), {'name': 'Alice', 'age': 25});
    });

    test('IntegerSegment toObject returns int', () {
      const segment = IntegerSegment(value: 42);
      expect(segment.toObject(), 42);
    });

    test('BooleanSegment toObject returns bool', () {
      const segment = BooleanSegment(value: true);
      expect(segment.toObject(), true);
    });

    test('NoneSegment toObject returns null', () {
      const segment = NoneSegment();
      expect(segment.toObject(), isNull);
      expect(segment.text, isNull);
    });

    test('ArrayStringSegment toObject returns List<String>', () {
      const segment = ArrayStringSegment(value: ['a', 'b', 'c']);
      expect(segment.toObject(), ['a', 'b', 'c']);
    });

    test('ArrayObjectSegment toObject returns List<Map>', () {
      final segment = ArrayObjectSegment(value: [
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);
      expect(segment.toObject(), [
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);
    });
  });

  group('VariablePool', () {
    late VariablePool pool;

    setUp(() {
      pool = VariablePool();
    });

    test('add and get basic string value', () {
      pool.add(['node1', 'output'], 'hello');
      final result = pool.get(['node1', 'output']);
      expect(result, isNotNull);
      expect(result!.toObject(), 'hello');
    });

    test('add and get object value', () {
      pool.add(['node1', 'data'], {'name': 'Alice', 'age': 25});
      final result = pool.get(['node1', 'data']);
      expect(result, isNotNull);
      expect(result!.toObject(), {'name': 'Alice', 'age': 25});
    });

    test('add and get integer value', () {
      pool.add(['node1', 'count'], 42);
      final result = pool.get(['node1', 'count']);
      expect(result, isNotNull);
      expect(result!.toObject(), 42);
    });

    test('add and get null value', () {
      pool.add(['node1', 'empty'], null);
      final result = pool.get(['node1', 'empty']);
      // null values are stored as NoneSegment
      expect(result, isNotNull);
      expect(result is NoneSegment, isTrue);
    });

    test('get non-existent key returns null', () {
      final result = pool.get(['node1', 'nonexistent']);
      expect(result, isNull);
    });

    test('get non-existent node returns null', () {
      final result = pool.get(['nonexistent_node', 'output']);
      expect(result, isNull);
    });

    test('multiple variables under same node', () {
      pool.add(['node1', 'a'], 'value_a');
      pool.add(['node1', 'b'], 'value_b');
      expect(pool.get(['node1', 'a'])!.toObject(), 'value_a');
      expect(pool.get(['node1', 'b'])!.toObject(), 'value_b');
    });

    test('overwrite existing value', () {
      pool.add(['node1', 'output'], 'old');
      pool.add(['node1', 'output'], 'new');
      expect(pool.get(['node1', 'output'])!.toObject(), 'new');
    });

    test('nested property access on ObjectSegment', () {
      pool.add(['node1', 'structured_output'], {
        'name': 'Alice',
        'age': 25,
      });
      // 访问 [node1, structured_output, name] 应穿透 ObjectSegment
      final result = pool.get(['node1', 'structured_output', 'name']);
      expect(result, isNotNull);
      expect(result!.toObject(), 'Alice');
    });

    test('nested property access on ObjectSegment deep', () {
      pool.add(['node1', 'data'], {
        'level1': {
          'level2': 'deep_value',
        },
      });
      final result = pool.get(['node1', 'data', 'level1', 'level2']);
      expect(result, isNotNull);
      expect(result!.toObject(), 'deep_value');
    });

    test('nested property access returns null for missing field', () {
      pool.add(['node1', 'data'], {'name': 'Alice'});
      final result = pool.get(['node1', 'data', 'missing']);
      expect(result, isNull);
    });

    test('nested property access on StringSegment returns null', () {
      pool.add(['node1', 'text'], 'plain string');
      final result = pool.get(['node1', 'text', 'some_field']);
      expect(result, isNull);
    });
  });

  group('VariablePool.convertTemplate', () {
    late VariablePool pool;

    setUp(() {
      pool = VariablePool();
    });

    test('replaces single {{#node_id.var#}} with value', () {
      pool.add(['node1', 'name'], 'Alice');
      final result = pool.convertTemplate('Hello {{#node1.name#}}!');
      expect(result.text, 'Hello Alice!');
    });

    test('replaces multiple {{#...#}} placeholders', () {
      pool.add(['node1', 'first'], 'Alice');
      pool.add(['node2', 'last'], 'Smith');
      final result =
          pool.convertTemplate('{{#node1.first#}} {{#node2.last#}}');
      expect(result.text, 'Alice Smith');
    });

    test('preserves text without placeholders', () {
      final result = pool.convertTemplate('No placeholders here');
      expect(result.text, 'No placeholders here');
    });

    test('unresolved placeholder preserved as empty string', () {
      // Dify behavior: unresolved variables become empty string
      final result = pool.convertTemplate('Hello {{#missing.var#}}!');
      expect(result.text, 'Hello !');
    });

    test('mixed resolved and unresolved', () {
      pool.add(['node1', 'name'], 'Alice');
      final result = pool.convertTemplate('{{#node1.name#}} {{#missing.var#}}');
      expect(result.text, 'Alice ');
    });

    test('placeholder with same node, different variables', () {
      pool.add(['start', 'query'], 'hello');
      pool.add(['start', 'cmd'], '特写');
      final result = pool
          .convertTemplate('cmd={{#start.cmd#}}, query={{#start.query#}}');
      expect(result.text, 'cmd=特写, query=hello');
    });

    test('numeric node IDs (as in Dify DSL)', () {
      pool.add(['1759138104711', 'user_input'], 'test input');
      final result =
          pool.convertTemplate('Input: {{#1759138104711.user_input#}}');
      expect(result.text, 'Input: test input');
    });

    test('convertTemplate returns SegmentGroup with segments', () {
      pool.add(['node1', 'name'], 'Alice');
      final group = pool.convertTemplate('Hello {{#node1.name#}}!');
      expect(group.segments.length, 3); // "Hello ", StringSegment, "!"
      expect(group.segments[0].text, 'Hello ');
      expect(group.segments[1].text, 'Alice');
      expect(group.segments[2].text, '!');
    });

    test('empty template returns empty text', () {
      final result = pool.convertTemplate('');
      expect(result.text, '');
    });

    test('placeholder adjacent to text', () {
      pool.add(['node1', 'val'], 'X');
      final result = pool.convertTemplate('A{{#node1.val#}}B');
      expect(result.text, 'AXB');
    });

    test('consecutive placeholders', () {
      pool.add(['n1', 'a'], 'A');
      pool.add(['n2', 'b'], 'B');
      final result = pool.convertTemplate('{{#n1.a#}}{{#n2.b#}}');
      expect(result.text, 'AB');
    });
  });

  group('SegmentGroup', () {
    test('text concatenates all segment texts', () {
      final group = SegmentGroup(segments: [
        const StringSegment(value: 'Hello '),
        const StringSegment(value: 'World'),
        const StringSegment(value: '!'),
      ]);
      expect(group.text, 'Hello World!');
    });

    test('empty segments list returns empty text', () {
      final group = SegmentGroup(segments: []);
      expect(group.text, '');
    });

    test('NoneSegment contributes empty string to text', () {
      final group = SegmentGroup(segments: [
        const StringSegment(value: 'A'),
        const NoneSegment(),
        const StringSegment(value: 'B'),
      ]);
      expect(group.text, 'AB');
    });
  });
}
