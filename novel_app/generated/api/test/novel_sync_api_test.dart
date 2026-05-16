import 'package:test/test.dart';
import 'package:novel_api/novel_api.dart';


/// tests for NovelSyncApi
void main() {
  final instance = NovelApi().getNovelSyncApi();

  group(NovelSyncApi, () {
    // Delete Synced Novel
    //
    // 删除已同步的小说数据.
    //
    //Future<NovelSyncDeleteResponse> deleteSyncedNovelApiNovelSyncDeleteDelete(String title, { String X_API_TOKEN }) async
    test('test deleteSyncedNovelApiNovelSyncDeleteDelete', () async {
      // TODO
    });

    // Download Novel
    //
    // 从服务器下载小说数据.
    //
    //Future<NovelSyncDownloadResponse> downloadNovelApiNovelSyncDownloadPost(NovelSyncDownloadRequest novelSyncDownloadRequest, { String X_API_TOKEN }) async
    test('test downloadNovelApiNovelSyncDownloadPost', () async {
      // TODO
    });

    // List Synced Novels
    //
    // 获取已同步小说列表.
    //
    //Future<NovelSyncListResponse> listSyncedNovelsApiNovelSyncListGet({ int page, int pageSize, String X_API_TOKEN }) async
    test('test listSyncedNovelsApiNovelSyncListGet', () async {
      // TODO
    });

    // Upload Novel
    //
    // 上传小说数据到服务器.
    //
    //Future<NovelSyncUploadResponse> uploadNovelApiNovelSyncUploadPost(NovelSyncUploadRequest novelSyncUploadRequest, { String X_API_TOKEN }) async
    test('test uploadNovelApiNovelSyncUploadPost', () async {
      // TODO
    });

  });
}
