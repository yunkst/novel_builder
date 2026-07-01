import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/models/chat_message_record.dart';
import 'package:novel_app/models/chat_session.dart';
import 'package:novel_app/models/hermes_message.dart';
import 'package:novel_app/repositories/chat_session_repository.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';

import '../../helpers/test_database_setup.dart';

/// ChatSessionRepository 集成测试
///
/// 覆盖：
/// - createSession / listSessionsByScenario / getSession / renameSession
/// - deleteSession（FK CASCADE 自动清消息）
/// - appendMessage 的事务原子性（orderIndex 单调 + updatedAt 同步）
/// - round-trip HermesMessage ↔ ChatMessageRecord（含 ToolCallSegment）
void main() {
  late ChatSessionRepository repo;
  late dynamic rawDb; // Database

  setUp(() async {
    final db = await TestDatabaseSetup.createInMemoryDatabase();
    final connection = DatabaseConnection.forTesting(db);
    // 连接层 PRAGMA foreign_keys 在 _onCreate/_onUpgrade 中已开，但测试侧
    // 直接用 openDatabase(':memory:') 跳过了那些回调，需要在这里手动开一次
    await db.execute('PRAGMA foreign_keys = ON');
    repo = ChatSessionRepository(dbConnection: connection);
    rawDb = db;
  });

  group('ChatSessionRepository', () {
    test('createSession + getSession round-trip', () async {
      final id = await repo.createSession(ChatSession(
        scenarioId: 'writing',
        title: '测试会话',
        currentNovelId: 42,
        currentNovelTitle: '测试书',
      ));
      expect(id, greaterThan(0));

      final session = await repo.getSession(id);
      expect(session, isNotNull);
      expect(session!.scenarioId, 'writing');
      expect(session.title, '测试会话');
      expect(session.currentNovelId, 42);
      expect(session.currentNovelTitle, '测试书');
      expect(session.createdAt.millisecondsSinceEpoch,
          lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch));
    });

    test('listSessionsByScenario 按 scenarioId 过滤 + 按 updatedAt DESC 排序',
        () async {
      final idA = await repo.createSession(ChatSession(
        scenarioId: 'writing',
        title: 'A',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ));
      final idB = await repo.createSession(ChatSession(
        scenarioId: 'writing',
        title: 'B',
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ));
      await repo.createSession(ChatSession(
        scenarioId: 'webview_extract',
        title: 'C',
      ));

      final list = await repo.listSessionsByScenario('writing');
      expect(list.length, 2);
      expect(list.map((e) => e.id).toList(), [idB, idA]); // 更新的在前
      expect(list.every((s) => s.scenarioId == 'writing'), isTrue);
    });

    test('renameSession 同时刷新 updatedAt', () async {
      final id = await repo.createSession(ChatSession(
        scenarioId: 'writing',
        title: '原始标题',
      ));
      final before = await repo.getSession(id);
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.renameSession(id, '新标题');

      final after = await repo.getSession(id);
      expect(after!.title, '新标题');
      expect(after.updatedAt.isAfter(before!.updatedAt), isTrue);
    });

    test('appendMessage 单调 orderIndex + 同时刷 session.updatedAt', () async {
      final sid = await repo.createSession(ChatSession(
        scenarioId: 'writing',
        title: '测试',
      ));
      final before = await repo.getSession(sid);
      await Future.delayed(const Duration(milliseconds: 5));

      // 第一次：orderIndex=0
      final m1 = ChatMessageRecord(
        sessionId: sid,
        role: 'user',
        content: 'hi',
        segmentsJson: HermesMessage.segmentsToJson(
            const [TextSegment('hi')]),
        orderIndex: 999, // 故意传错，验证内部覆盖
      );
      final id1 = await repo.appendMessage(m1);

      // 第二次：orderIndex=1
      final m2 = ChatMessageRecord(
        sessionId: sid,
        role: 'assistant',
        content: 'hello',
        segmentsJson: '[]',
        orderIndex: 999,
      );
      final id2 = await repo.appendMessage(m2);

      final messages = await repo.listMessages(sid);
      expect(messages.length, 2);
      expect(messages[0].orderIndex, 0);
      expect(messages[1].orderIndex, 1);
      expect(messages[0].id, id1);
      expect(messages[1].id, id2);

      final after = await repo.getSession(sid);
      expect(after!.updatedAt.isAfter(before!.updatedAt), isTrue);

      // getMessageCount
      expect(await repo.getMessageCount(sid), 2);
    });

    test('appendMessage 失败时 transaction 回滚，orderIndex 不出现空洞', () async {
      final sid = await repo.createSession(ChatSession(
        scenarioId: 'writing',
        title: '回滚测试',
      ));

      // 先写一条 orderIndex=0
      await repo.appendMessage(ChatMessageRecord(
        sessionId: sid,
        role: 'user',
        content: 'first',
        segmentsJson: '[]',
        orderIndex: 0,
      ));

      // 第二次写时主动制造失败：sessionId 指向不存在的 session，触发 FK 违规
      // sqflite 在 insert 阶段校验 FK，违反会抛异常
      // 我们的 transaction 应整体回滚
      bool threw = false;
      try {
        await rawDb.transaction((txn) async {
          await txn.insert('chat_messages', {
            'sessionId': 99999,
            'role': 'user',
            'content': 'bad',
            'segmentsJson': '[]',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'orderIndex': 0,
          });
          // 同步更新一个不存在的会话也应该会失败或 0 affected
          await txn.update('chat_sessions', {'updatedAt': 0},
              where: 'id = ?', whereArgs: [99999]);
        });
      } catch (e) {
        threw = true;
      }
      expect(threw, isTrue);

      // 再次正常写，orderIndex 应继续递增（不出现空洞，因为前一次完全回滚）
      final id = await repo.appendMessage(ChatMessageRecord(
        sessionId: sid,
        role: 'user',
        content: 'second',
        segmentsJson: '[]',
        orderIndex: 0,
      ));
      final msgs = await repo.listMessages(sid);
      // 应该有 2 条：第一条 + 这次写的
      expect(msgs.length, 2);
      // 第二条 orderIndex 应为 1（第一条是 0，没有因为回滚而出现 1 也没了）
      final last = msgs.last;
      expect(last.id, id);
      expect(last.orderIndex, 1);
    });

    test('HermesMessage 含 ToolCallSegment 能完整 round-trip', () async {
      final sid = await repo.createSession(ChatSession(
        scenarioId: 'writing',
        title: 'tool round-trip',
      ));
      final original = HermesMessage.assistantFromSegments(const [
        TextSegment('我先想一下'),
        ToolCallSegment(AgentToolCall(
          id: 'call-1',
          name: 'search_novel',
          arguments: {'query': '修仙'},
          status: AgentToolStatus.completed,
          result: '{"success":true,"results":[]}',
        )),
        TextSegment('查完再回复你'),
        ToolCallSegment(AgentToolCall(
          id: 'call-2',
          name: 'select_novel',
          arguments: {'novelId': 7},
          status: AgentToolStatus.error,
          result: null,
        )),
      ]);

      await repo.appendMessage(ChatMessageRecord.fromHermesMessage(
        sid,
        0, // orderIndex 忽略
        original,
      ));

      final loaded = (await repo.listMessages(sid)).first;
      final segs = loaded.segments;
      expect(segs.length, 4);
      expect((segs[0] as TextSegment).content, '我先想一下');
      expect((segs[1] as ToolCallSegment).call.id, 'call-1');
      expect((segs[1] as ToolCallSegment).call.name, 'search_novel');
      expect((segs[1] as ToolCallSegment).call.arguments['query'], '修仙');
      expect((segs[1] as ToolCallSegment).call.status,
          AgentToolStatus.completed);
      expect((segs[1] as ToolCallSegment).call.result,
          '{"success":true,"results":[]}');
      expect((segs[3] as ToolCallSegment).call.status, AgentToolStatus.error);
    });

    test('HermesMessage.segmentsFromJson 坏数据降级为空', () {
      // 1) 非 list
      expect(
          HermesMessage.segmentsFromJson('"not a list"'), isEmpty);
      // 2) 非法 JSON
      expect(HermesMessage.segmentsFromJson('{broken'), isEmpty);
      // 3) item 非 Map
      expect(HermesMessage.segmentsFromJson('[1,2,3]'), isEmpty);
      // 4) 未知 type 跳过
      final result = HermesMessage.segmentsFromJson(
          '[{"type":"unknown","foo":"bar"},{"type":"text","content":"ok"}]');
      expect(result.length, 1);
      expect((result.first as TextSegment).content, 'ok');
    });

    test('deleteSession 经 FK CASCADE 自动删 messages', () async {
      final sid = await repo.createSession(ChatSession(
        scenarioId: 'writing',
        title: 'CASCADE 测试',
      ));
      await repo.appendMessage(ChatMessageRecord(
        sessionId: sid,
        role: 'user',
        content: 'm1',
        segmentsJson: '[]',
        orderIndex: 0,
      ));
      await repo.appendMessage(ChatMessageRecord(
        sessionId: sid,
        role: 'assistant',
        content: 'm2',
        segmentsJson: '[]',
        orderIndex: 0,
      ));
      expect(await repo.getMessageCount(sid), 2);

      final affected = await repo.deleteSession(sid);
      expect(affected, 1);
      expect(await repo.getSession(sid), isNull);
      expect(await repo.getMessageCount(sid), 0); // CASCADE 删干净
    });

    test('touchSession 单独刷 updatedAt', () async {
      final sid = await repo.createSession(ChatSession(
        scenarioId: 'writing',
        title: 'touch',
      ));
      final before = await repo.getSession(sid);
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.touchSession(sid);
      final after = await repo.getSession(sid);
      expect(after!.updatedAt.isAfter(before!.updatedAt), isTrue);
      expect(after.title, 'touch'); // 标题不变
    });
  });
}
