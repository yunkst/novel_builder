/// Provider 默认值配置
///
/// 此文件定义 Provider 的默认值和常量
library;

/// 默认书架 ID
///
/// 用于标识"全部小说"书架
const int defaultBookshelfId = 1;

/// 默认每页数量
///
/// 分页查询时的默认每页数量
const int defaultPageSize = 20;

/// 最大缓存大小
///
/// 章节缓存的最大 MB 数
const int maxCacheSizeMB = 500;

/// 缓存清理阈值
///
/// 当缓存超过此值时触发清理 (MB)
const int cacheCleanupThresholdMB = 400;

/// 预加载并发数
///
/// 同时预加载的章节数量
const int preloadConcurrency = 3;

/// 搜索结果最大数量
///
/// 搜索 API 返回的最大结果数
const int maxSearchResults = 50;
