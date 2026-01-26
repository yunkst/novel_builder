/// 边权重管理器
///
/// 管理力导向图中所有边的动态权重，用于实现节点交互时的引力调整

class EdgeWeightManager {
  // 边权重映射：key为边标识（方向无关），value为权重值
  final Map<String, double> _weights = {};

  /// 获取边的权重
  ///
  /// [sourceId] 源节点ID
  /// [targetId] 目标节点ID
  /// 返回权重值，默认为1.0（正常引力）
  double getWeight(int sourceId, int targetId) {
    final key = _getEdgeKey(sourceId, targetId);
    return _weights[key] ?? 1.0;
  }

  /// 设置边的权重
  ///
  /// [sourceId] 源节点ID
  /// [targetId] 目标节点ID
  /// [weight] 权重值（1.0=正常，2.5=增强）
  void setWeight(int sourceId, int targetId, double weight) {
    final key = _getEdgeKey(sourceId, targetId);
    _weights[key] = weight;
  }

  /// 提高与指定节点相连的所有边的权重
  ///
  /// [nodeId] 节点ID
  /// [connectedNodeIds] 与该节点相连的所有节点ID列表
  /// [enhancedWeight] 增强权重值，默认2.5
  void enhanceNodeEdges(
    int nodeId,
    List<int> connectedNodeIds, {
    double enhancedWeight = 2.5,
  }) {
    for (final connectedId in connectedNodeIds) {
      setWeight(nodeId, connectedId, enhancedWeight);
    }
  }

  /// 重置所有边的权重为默认值
  void reset() {
    _weights.clear();
  }

  /// 生成方向无关的边键标识
  ///
  /// 确保边A-B和边B-A使用相同的键
  String _getEdgeKey(int id1, int id2) {
    final smaller = id1 < id2 ? id1 : id2;
    final larger = id1 < id2 ? id2 : id1;
    return '$smaller-$larger';
  }

  /// 获取所有边的权重映射（只读）
  Map<String, double> getAllWeights() {
    return Map.unmodifiable(_weights);
  }
}
