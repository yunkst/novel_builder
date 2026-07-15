import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/site_script.dart';

void main() {
  group('SiteScript ocr 字段', () {
    test('fromMap 读 ocr 列（1 → true）', () {
      final s = SiteScript.fromMap({
        'id': '1',
        'domain': 'a.com',
        'url_pattern': '',
        'chapter_list_js': '',
        'chapter_content_js': '',
        'sample_url': '',
        'created_at': 0,
        'last_used_at': 0,
        'use_count': 0,
        'verified': 0,
        'ocr': 1,
      });
      expect(s.ocr, isTrue);
      expect(s.needsOcr, isTrue);
    });

    test('fromMap 读 ocr 列（缺失/0/null → false）', () {
      final map = <String, dynamic>{
        'id': '1',
        'domain': 'a.com',
        'url_pattern': '',
        'chapter_list_js': '',
        'chapter_content_js': '',
        'sample_url': '',
        'created_at': 0,
        'last_used_at': 0,
        'use_count': 0,
        'verified': 0,
      };
      expect(SiteScript.fromMap(map).ocr, isFalse);
      expect(SiteScript.fromMap({...map, 'ocr': 0}).ocr, isFalse);
      expect(SiteScript.fromMap({...map, 'ocr': null}).ocr, isFalse);
    });

    test('toMap 写 ocr（true→1, false→0）', () {
      final base = SiteScript(
        id: '1',
        domain: 'a.com',
        urlPattern: '',
        chapterListJs: '',
        chapterContentJs: '',
        sampleUrl: '',
        createdAt: 0,
        lastUsedAt: 0,
        useCount: 0,
        verified: 0,
        ocr: true,
      );
      expect(base.toMap()['ocr'], 1);
      expect(base.copyWith(ocr: false).toMap()['ocr'], 0);
    });

    test('copyWith 覆盖 ocr', () {
      final s = SiteScript(
        id: '1',
        domain: 'a.com',
        urlPattern: '',
        chapterListJs: '',
        chapterContentJs: '',
        sampleUrl: '',
        createdAt: 0,
        lastUsedAt: 0,
        useCount: 0,
        verified: 0,
        ocr: false,
      );
      expect(s.copyWith(ocr: true).ocr, isTrue);
      expect(s.copyWith().ocr, isFalse); // 不传保持原值
    });

    test('构造默认 ocr=false（向后兼容）', () {
      final s = SiteScript(
        id: '1',
        domain: 'a.com',
        urlPattern: '',
        chapterListJs: '',
        chapterContentJs: '',
        sampleUrl: '',
        createdAt: 0,
        lastUsedAt: 0,
        useCount: 0,
        verified: 0,
      );
      expect(s.ocr, isFalse);
      expect(s.needsOcr, isFalse);
    });
  });
}
