/// 双端队列 (Double-Ended Queue)
///
/// 支持在队列头部和尾部高效地插入和删除元素
class Deque<T> {
  final List<T> _list = [];

  /// 在队列头部插入元素
  void addFirst(T item) => _list.insert(0, item);

  /// 在队列尾部插入元素
  void addLast(T item) => _list.add(item);

  /// 移除并返回队列头部元素
  T removeFirst() {
    if (_list.isEmpty) {
      throw StateError('Cannot removeFirst from empty Deque');
    }
    return _list.removeAt(0);
  }

  /// 移除并返回队列尾部元素
  T removeLast() {
    if (_list.isEmpty) {
      throw StateError('Cannot removeLast from empty Deque');
    }
    return _list.removeLast();
  }

  /// 查看队列头部元素（不移除）
  T get first {
    if (_list.isEmpty) {
      throw StateError('Cannot get first from empty Deque');
    }
    return _list.first;
  }

  /// 查看队列尾部元素（不移除）
  T get last {
    if (_list.isEmpty) {
      throw StateError('Cannot get last from empty Deque');
    }
    return _list.last;
  }

  /// 队列是否为空
  bool get isEmpty => _list.isEmpty;

  /// 队列是否不为空
  bool get isNotEmpty => _list.isNotEmpty;

  /// 队列长度
  int get length => _list.length;

  /// 获取队列的可迭代对象（用于遍历）
  Iterable<T> get iterable => _list;

  /// 清空队列
  void clear() {
    _list.clear();
  }

  @override
  String toString() {
    if (isEmpty) return 'Deque[]';
    return 'Deque[${_list.map((e) => e.toString()).join(', ')}]';
  }
}
