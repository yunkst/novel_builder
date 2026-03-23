import 'package:test/test.dart';
import 'package:novel_api/novel_api.dart';


/// tests for NovelSyncApi
void main() {
  final instance = NovelApi().getNovelSyncApi();

  group(NovelSyncApi, () {
    // Delete Synced Novel
    //
    // 删除已同步的小说数据.  从服务器删除指定小说的所有同步数据，包括章节、角色、关系和大纲。  **查询参数:** - **novel_url**: 小说URL（作为唯一标识）  **返回值:** - **success**: 是否成功 - **message**: 响应消息  **认证**: 需要X-API-TOKEN header  **注意:** 此操作不可逆，删除后数据无法恢复
    //
    //Future<JsonObject> deleteSyncedNovelApiNovelSyncDeleteDelete(String novelUrl, { String X_API_TOKEN }) async
    test('test deleteSyncedNovelApiNovelSyncDeleteDelete', () async {
      // TODO
    });

    // Download Novel
    //
    // 从服务器下载小说数据.  根据小说来源URL（source_url）获取服务器上存储的完整小说数据。 支持选择性下载章节、角色和大纲数据。  **请求参数:** - **device_id**: 设备标识 - **source_url**: 小说来源URL（作为唯一标识，与上传时一致） - **include_chapters**: 是否包含章节内容（默认true） - **include_characters**: 是否包含角色数据（默认true） - **include_outlines**: 是否包含大纲数据（默认true）  **返回值:** - **success**: 是否成功 - **message**: 响应消息 - **novel_data**: 完整的小说数据（如果找到） - **sync_version**: 同步版本号 - **synced_at**: 最后同步时间  **认证**: 需要X-API-TOKEN header  **注意:** 如果小说不存在，返回success=false，novel_data=null
    //
    //Future<NovelSyncDownloadResponse> downloadNovelApiNovelSyncDownloadPost(NovelSyncDownloadRequest novelSyncDownloadRequest, { String X_API_TOKEN }) async
    test('test downloadNovelApiNovelSyncDownloadPost', () async {
      // TODO
    });

    // List Synced Novels
    //
    // 获取已同步小说列表.  返回服务器上所有已同步小说的基本信息列表，支持分页。 返回的数据仅包含元数据，不包含章节内容。  **查询参数:** - **page**: 页码（从1开始，默认1） - **page_size**: 每页数量（默认20，最大100）  **返回值:** - **success**: 是否成功 - **message**: 响应消息 - **novels**: 小说元数据列表 - **total_count**: 总数 - **page**: 当前页码 - **page_size**: 每页数量  **认证**: 需要X-API-TOKEN header
    //
    //Future<NovelSyncListResponse> listSyncedNovelsApiNovelSyncListGet({ int page, int pageSize, String X_API_TOKEN }) async
    test('test listSyncedNovelsApiNovelSyncListGet', () async {
      // TODO
    });

    // Upload Novel
    //
    // 上传小说数据到服务器.  接收APP端上传的完整小说数据，包括章节、角色、关系和大纲等信息。 服务器会根据source_url作为唯一标识存储数据，支持版本控制。  **请求参数:** - **device_id**: 设备标识（用于追踪同步来源） - **novel_data**: 完整的小说数据，包括：     - 基本信息（标题、作者、简介等）     - 章节列表（包括用户插入章节）     - 角色列表     - 角色关系列表     - 大纲列表 - **force_overwrite**: 是否强制覆盖服务器数据（默认false）  **返回值:** - **success**: 是否成功 - **message**: 响应消息 - **novel_id**: 小说ID - **sync_version**: 同步版本号（每次更新递增） - **synced_at**: 同步时间  **认证**: 需要X-API-TOKEN header
    //
    //Future<NovelSyncUploadResponse> uploadNovelApiNovelSyncUploadPost(NovelSyncUploadRequest novelSyncUploadRequest, { String X_API_TOKEN }) async
    test('test uploadNovelApiNovelSyncUploadPost', () async {
      // TODO
    });

  });
}
