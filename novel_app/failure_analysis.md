# 失败测试详细分析报告

生成时间: 2026年01月30日 22:36:09

## 分析: test/unit/controllers/chapter_loader_test.dart
```
test/unit/controllers/chapter_loader_test.dart:98:49: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final cached = await base.databaseService.getChapters(novel.url);
--
test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/controllers/chapter_loader_test.dart: test/unit/controllers/chapter_loader_test.dart:98:49: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final cached = await base.databaseService.getChapters(novel.url);
--
  test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
--
  test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
```

## 分析: test/unit/controllers/chapter_reorder_controller_test.dart
```
test/unit/controllers/chapter_reorder_controller_test.dart:90:51: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await base.databaseService.getChapters(novel.url);
--
test/unit/controllers/chapter_reorder_controller_test.dart:111:50: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final updated = await base.databaseService.getChapters(novel.url);
--
test/unit/controllers/chapter_reorder_controller_test.dart:133:51: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await base.databaseService.getChapters(novel.url);
--
test/unit/controllers/chapter_reorder_controller_test.dart:153:50: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final updated = await base.databaseService.getChapters(novel.url);
--
test/unit/controllers/chapter_reorder_controller_test.dart:171:51: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await base.databaseService.getChapters(novel.url);
--
test/unit/controllers/chapter_reorder_controller_test.dart:187:53: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final firstQuery = await base.databaseService.getChapters(novel.url);
--
test/unit/controllers/chapter_reorder_controller_test.dart:188:54: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final secondQuery = await base.databaseService.getChapters(novel.url);
--
lib/controllers/chapter_list/chapter_reorder_controller.dart:41:28: Error: The method 'updateChaptersOrder' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'updateChaptersOrder'.
    await _databaseService.updateChaptersOrder(novelUrl, chapters);
--
test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/controllers/chapter_reorder_controller_test.dart: test/unit/controllers/chapter_reorder_controller_test.dart:90:51: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final chapters = await base.databaseService.getChapters(novel.url);
--
  test/unit/controllers/chapter_reorder_controller_test.dart:111:50: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final updated = await base.databaseService.getChapters(novel.url);
--
  test/unit/controllers/chapter_reorder_controller_test.dart:133:51: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final chapters = await base.databaseService.getChapters(novel.url);
--
  test/unit/controllers/chapter_reorder_controller_test.dart:153:50: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final updated = await base.databaseService.getChapters(novel.url);
--
  test/unit/controllers/chapter_reorder_controller_test.dart:171:51: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final chapters = await base.databaseService.getChapters(novel.url);
--
  test/unit/controllers/chapter_reorder_controller_test.dart:187:53: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final firstQuery = await base.databaseService.getChapters(novel.url);
--
  test/unit/controllers/chapter_reorder_controller_test.dart:188:54: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final secondQuery = await base.databaseService.getChapters(novel.url);
--
  lib/controllers/chapter_list/chapter_reorder_controller.dart:41:28: Error: The method 'updateChaptersOrder' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'updateChaptersOrder'.
      await _databaseService.updateChaptersOrder(novelUrl, chapters);
--
  test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
--
  test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
```

## 分析: test/unit/services/ai_accompaniment_background_test.dart
```
test/unit/services/ai_accompaniment_background_test.dart:42:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:67:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:98:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:125:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:139:55: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        final result = await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:161:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:170:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:179:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:201:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:235:42: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:272:42: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:329:42: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:406:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:431:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:459:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/unit/services/ai_accompaniment_background_test.dart:492:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
        await testBase.databaseService.appendBackgroundSetting(
--
test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/services/ai_accompaniment_background_test.dart: test/unit/services/ai_accompaniment_background_test.dart:42:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:67:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:98:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:125:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:139:55: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          final result = await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:161:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:170:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:179:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:201:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:235:42: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
            await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:272:42: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
            await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:329:42: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
            await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:406:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:431:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:459:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/unit/services/ai_accompaniment_background_test.dart:492:40: Error: The method 'appendBackgroundSetting' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'appendBackgroundSetting'.
          await testBase.databaseService.appendBackgroundSetting(
--
  test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
--
  test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
```

## 分析: test/unit/services/ai_accompaniment_database_test.dart
```
test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/services/ai_accompaniment_database_test.dart: test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
--
  test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
```

## 分析: test/unit/services/batch_chapter_loading_test.dart
```
```

## 分析: test/unit/services/chapter_service_test.dart
```
test/unit/services/chapter_service_test.dart:655:34: Error: The method 'close' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'close'.
      await base.databaseService.close();
--
test/unit/services/chapter_service_test.dart:677:34: Error: The method 'close' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'close'.
      await base.databaseService.close();
--
test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/services/chapter_service_test.dart: test/unit/services/chapter_service_test.dart:655:34: Error: The method 'close' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'close'.
        await base.databaseService.close();
--
  test/unit/services/chapter_service_test.dart:677:34: Error: The method 'close' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'close'.
        await base.databaseService.close();
--
  test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
--
  test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
```

## 分析: test/unit/services/character_auto_save_logic_test.dart
```
  UnimplementedError: CharacterRepository 依赖 DatabaseService 管理数据库实例
  package:novel_app/repositories/character_repository.dart 22:5   CharacterRepository.initDatabase
  package:novel_app/repositories/base_repository.dart 18:23       BaseRepository.database
  package:novel_app/repositories/character_repository.dart 34:22  CharacterRepository.createCharacter
--
  UnimplementedError: CharacterRepository 依赖 DatabaseService 管理数据库实例
  package:novel_app/repositories/character_repository.dart 22:5   CharacterRepository.initDatabase
  package:novel_app/repositories/base_repository.dart 18:23       BaseRepository.database
  package:novel_app/repositories/character_repository.dart 34:22  CharacterRepository.createCharacter
--
  UnimplementedError: CharacterRepository 依赖 DatabaseService 管理数据库实例
  package:novel_app/repositories/character_repository.dart 22:5   CharacterRepository.initDatabase
  package:novel_app/repositories/base_repository.dart 18:23       BaseRepository.database
  package:novel_app/repositories/character_repository.dart 34:22  CharacterRepository.createCharacter
--
  UnimplementedError: CharacterRepository 依赖 DatabaseService 管理数据库实例
  package:novel_app/repositories/character_repository.dart 22:5   CharacterRepository.initDatabase
  package:novel_app/repositories/base_repository.dart 18:23       BaseRepository.database
  package:novel_app/repositories/character_repository.dart 34:22  CharacterRepository.createCharacter
```

## 分析: test/unit/services/character_drop_first_last_test.dart
```
```

## 分析: test/unit/services/character_extraction_bug_test.dart
```
```

## 分析: test/unit/services/character_extraction_service_test.dart
```
```

## 分析: test/unit/services/character_merge_test.dart
```
```

## 分析: test/unit/services/character_relationship_database_test.dart
```
test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/services/character_relationship_database_test.dart: test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
--
  test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
```

## 分析: test/unit/services/database_lock_fix_verification_test.dart
```
test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
    final chapters = await databaseService.getChapters(novelUrl);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/services/database_lock_fix_verification_test.dart: test/base/database_test_base.dart:282:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
--
  test/base/database_test_base.dart:332:44: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await databaseService.getChapters(novelUrl);
```

## 分析: test/unit/services/database_service_test.dart
```
test/unit/services/database_service_test.dart:128:23: Error: The method 'clearAllCache' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'clearAllCache'.
      await dbService.clearAllCache();
--
test/unit/services/database_service_test.dart:172:23: Error: The method 'clearNovelCache' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'clearNovelCache'.
      await dbService.clearNovelCache(testNovel.url);
--
test/unit/services/database_service_test.dart:186:23: Error: The method 'clearAllCache' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'clearAllCache'.
      await dbService.clearAllCache();
--
test/unit/services/database_service_test.dart:197:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
      await dbService.insertUserChapter(
--
test/unit/services/database_service_test.dart:219:23: Error: The method 'createCustomNovel' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'createCustomNovel'.
      await dbService.createCustomNovel(testNovel.title, testNovel.author);
--
test/unit/services/database_service_test.dart:222:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
      await dbService.insertUserChapter(
--
test/unit/services/database_service_test.dart:229:40: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await dbService.getChapters(testNovel.url);
--
test/unit/services/database_service_test.dart:241:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
      await dbService.insertUserChapter(
--
test/unit/services/database_service_test.dart:249:38: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      var chapters = await dbService.getChapters(testNovel.url);
--
test/unit/services/database_service_test.dart:256:34: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      chapters = await dbService.getChapters(testNovel.url);
--
test/unit/services/database_service_test.dart:262:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
      await dbService.insertUserChapter(
--
test/unit/services/database_service_test.dart:268:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
      await dbService.insertUserChapter(
--
test/unit/services/database_service_test.dart:274:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
      await dbService.insertUserChapter(
--
test/unit/services/database_service_test.dart:282:40: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await dbService.getChapters(testNovel.url);
--
test/unit/services/database_service_test.dart:286:47: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final updatedChapters = await dbService.getChapters(testNovel.url);
--
test/unit/services/database_service_test.dart:299:23: Error: The method 'clearAllCache' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'clearAllCache'.
      await dbService.clearAllCache();
--
test/unit/services/database_service_test.dart:309:45: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final savedChapters = await dbService.getChapters(testNovel.url);
--
test/unit/services/database_service_test.dart:317:40: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final chapters = await dbService.getChapters('non-existent-novel-url');
--
test/unit/services/database_service_test.dart:329:23: Error: The method 'updateChaptersOrder' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'updateChaptersOrder'.
      await dbService.updateChaptersOrder(testNovel.url, reorderedChapters);
--
test/unit/services/database_service_test.dart:331:45: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
      final savedChapters = await dbService.getChapters(testNovel.url);
--
test/unit/services/database_service_test.dart:363:23: Error: The method 'clearAllCache' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'clearAllCache'.
      await dbService.clearAllCache();
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/services/database_service_test.dart: test/unit/services/database_service_test.dart:128:23: Error: The method 'clearAllCache' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'clearAllCache'.
        await dbService.clearAllCache();
--
  test/unit/services/database_service_test.dart:172:23: Error: The method 'clearNovelCache' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'clearNovelCache'.
        await dbService.clearNovelCache(testNovel.url);
--
  test/unit/services/database_service_test.dart:186:23: Error: The method 'clearAllCache' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'clearAllCache'.
        await dbService.clearAllCache();
--
  test/unit/services/database_service_test.dart:197:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
        await dbService.insertUserChapter(
--
  test/unit/services/database_service_test.dart:219:23: Error: The method 'createCustomNovel' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'createCustomNovel'.
        await dbService.createCustomNovel(testNovel.title, testNovel.author);
--
  test/unit/services/database_service_test.dart:222:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
        await dbService.insertUserChapter(
--
  test/unit/services/database_service_test.dart:229:40: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final chapters = await dbService.getChapters(testNovel.url);
--
  test/unit/services/database_service_test.dart:241:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
        await dbService.insertUserChapter(
--
  test/unit/services/database_service_test.dart:249:38: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        var chapters = await dbService.getChapters(testNovel.url);
--
  test/unit/services/database_service_test.dart:256:34: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        chapters = await dbService.getChapters(testNovel.url);
--
  test/unit/services/database_service_test.dart:262:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
        await dbService.insertUserChapter(
--
  test/unit/services/database_service_test.dart:268:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
        await dbService.insertUserChapter(
--
  test/unit/services/database_service_test.dart:274:23: Error: The method 'insertUserChapter' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'insertUserChapter'.
        await dbService.insertUserChapter(
--
  test/unit/services/database_service_test.dart:282:40: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final chapters = await dbService.getChapters(testNovel.url);
--
  test/unit/services/database_service_test.dart:286:47: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final updatedChapters = await dbService.getChapters(testNovel.url);
--
  test/unit/services/database_service_test.dart:299:23: Error: The method 'clearAllCache' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'clearAllCache'.
        await dbService.clearAllCache();
--
  test/unit/services/database_service_test.dart:309:45: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final savedChapters = await dbService.getChapters(testNovel.url);
--
  test/unit/services/database_service_test.dart:317:40: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final chapters = await dbService.getChapters('non-existent-novel-url');
--
  test/unit/services/database_service_test.dart:329:23: Error: The method 'updateChaptersOrder' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'updateChaptersOrder'.
        await dbService.updateChaptersOrder(testNovel.url, reorderedChapters);
--
  test/unit/services/database_service_test.dart:331:45: Error: The method 'getChapters' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapters'.
        final savedChapters = await dbService.getChapters(testNovel.url);
--
  test/unit/services/database_service_test.dart:363:23: Error: The method 'clearAllCache' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'clearAllCache'.
        await dbService.clearAllCache();
```

## 分析: test/unit/services/novels_view_test.dart
```
```

## 分析: test/unit/services/scene_illustration_service_test.dart
```
test/unit/services/scene_illustration_service_test.dart:230:38: Error: The method 'getCachedChapterContent' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getCachedChapterContent'.
            final content = await db.getCachedChapterContent(testChapterId);
--
test/unit/services/scene_illustration_service_test.dart:536:35: Error: The method 'getCachedChapterContent' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getCachedChapterContent'.
  final currentContent = await db.getCachedChapterContent(chapterId);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/services/scene_illustration_service_test.dart: test/unit/services/scene_illustration_service_test.dart:230:38: Error: The method 'getCachedChapterContent' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getCachedChapterContent'.
              final content = await db.getCachedChapterContent(testChapterId);
--
  test/unit/services/scene_illustration_service_test.dart:536:35: Error: The method 'getCachedChapterContent' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getCachedChapterContent'.
    final currentContent = await db.getCachedChapterContent(chapterId);
```

## 分析: test/unit/services/tts_player_service_test.dart
```
lib/services/tts_player_service.dart:546:38: Error: The method 'getChapterContent' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapterContent'.
      final cached = await _database.getChapterContent(chapter.url);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/services/tts_player_service_test.dart: lib/services/tts_player_service.dart:546:38: Error: The method 'getChapterContent' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapterContent'.
        final cached = await _database.getChapterContent(chapter.url);
```

## 分析: test/unit/widgets/tts_widgets_test.dart
```
lib/services/tts_player_service.dart:546:38: Error: The method 'getChapterContent' isn't defined for the type 'DatabaseService'.
 - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'getChapterContent'.
      final cached = await _database.getChapterContent(chapter.url);
--
  Compilation failed for testPath=D:/myspace/novel_builder/novel_app/test/unit/widgets/tts_widgets_test.dart: lib/services/tts_player_service.dart:546:38: Error: The method 'getChapterContent' isn't defined for the type 'DatabaseService'.
   - 'DatabaseService' is from 'package:novel_app/services/database_service.dart' ('lib/services/database_service.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'getChapterContent'.
        final cached = await _database.getChapterContent(chapter.url);
```

