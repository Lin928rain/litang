import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/auth/cas_client.dart';
import 'package:project_usst/data/chaoxing/chaoxing_course_detail.dart';
import 'package:project_usst/data/lms/exam_forum_api.dart';

class _FakeCasClient extends CasClient {
  _FakeCasClient(this.routes);

  final Map<String, String> routes;

  /// 记录发出去的 POST（校验发帖请求体）。
  final List<Map<String, Object>> posted = <Map<String, Object>>[];

  @override
  Future<Response<String>> getApi(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final body = routes[uri.path];
    if (body == null) {
      throw StateError('未预置响应：${uri.path}');
    }
    return Response<String>(
      requestOptions: RequestOptions(path: uri.path),
      statusCode: 200,
      data: body,
    );
  }

  @override
  Future<Response<String>> sendJson(
    Uri uri, {
    String method = 'POST',
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    posted.add(<String, Object>{'path': uri.path, 'data': data});
    return Response<String>(
      requestOptions: RequestOptions(path: uri.path),
      statusCode: 201,
      data: '{}',
    );
  }
}

void main() {
  group('学习通考试列表解析', () {
    test('抽出考试 id、状态、分数和答卷分析地址', () {
      const html = '''
<ul>
<li>
  <div onclick="viewExamAnswer('11005783','171466380')">
    <p class="overHidden2 fl">第1章选择题专项测验</p>
    <p class="status fl">已完成</p>
    <a href="https://stat2-ans.chaoxing.com/study-knowledge/ans?courseid=1&amp;relationId=11005783&amp;type=4" class="listSubmit fl insightBtn">智能分析</a>
  </div>
  <div class="time"><span class="numspan"> 100 <i>分</i></span></div>
  <div>剩余7小时53分钟</div>
</li>
</ul>
''';

      final exams = ChaoxingCourseDetailApi.parseExams(html);

      expect(exams, hasLength(1));
      final exam = exams.single;
      expect(exam.id, '11005783');
      expect(exam.title, '第1章选择题专项测验');
      expect(exam.status, '已完成');
      expect(exam.score, '100');
      expect(exam.remaining, contains('剩余7小时53分钟'));
      expect(exam.analysisUrl, contains('stat2-ans.chaoxing.com'));
      // &amp; 要被还原成 &
      expect(exam.analysisUrl, contains('relationId=11005783'));
      expect(exam.analysisUrl, isNot(contains('&amp;')));
    });

    test('没有「智能分析」链接时 analysisUrl 为空', () {
      const html = '''
<li>
  <p class="overHidden2 fl">随堂测</p>
  <p class="status fl">已过期</p>
</li>
''';
      final exams = ChaoxingCourseDetailApi.parseExams(html);
      expect(exams.single.analysisUrl, isEmpty);
      expect(exams.single.status, '已过期');
    });

    test('空页面返回空列表', () {
      expect(ChaoxingCourseDetailApi.parseExams('<ul>暂无考试</ul>'), isEmpty);
    });
  });

  group('一网畅学考试详情', () {
    test('解析考试元信息 + 得分 + 提交记录', () async {
      final api = TronExamForumApi(
        _FakeCasClient(<String, String>{
          '/api/exams/198881':
              '{"title":"第一单元作业","description":"<p>闭卷</p>",'
              '"start_time":"2026-09-24T06:30:00Z",'
              '"end_time":"2026-10-11T15:59:00Z",'
              '"is_closed":true,"is_started":true,'
              '"subjects_count":10,"total_points":100,'
              '"submit_times":2,"submitted_times":2}',
          '/api/exams/198881/submissions':
              '{"exam_score":80.0,"submissions":['
              '{"id":4415141,"score":"80.0","submitted_at":"2026-09-26T09:03:59Z",'
              '"submit_method_text":"手动交卷"}]}',
        }),
      );

      final detail = await api.fetchExam(198881);

      expect(detail.title, '第一单元作业');
      expect(detail.description, '闭卷');
      expect(detail.status, '已结束');
      expect(detail.closed, isTrue);
      expect(detail.subjectsCount, 10);
      expect(detail.totalPoints, 100);
      expect(detail.submitTimes, 2);
      expect(detail.submittedTimes, 2);
      expect(detail.score, 80);
      expect(detail.submissions, hasLength(1));
      expect(detail.submissions.single.methodText, '手动交卷');
      expect(detail.submissions.single.score, 80);
      expect(detail.submissions.single.submittedAt, isNotEmpty);
    });

    test('分数接口失败时仍返回考试基本信息', () async {
      final api = TronExamForumApi(
        _FakeCasClient(<String, String>{
          '/api/exams/7': '{"title":"小测","is_started":true,"subjects_count":3}',
          // submissions 故意不预置：抛异常后应降级
        }),
      );

      final detail = await api.fetchExam(7);

      expect(detail.title, '小测');
      expect(detail.status, '进行中');
      expect(detail.score, isNull);
      expect(detail.submissions, isEmpty);
    });
  });

  group('一网畅学讨论详情', () {
    test('解析话题、作者与回复', () async {
      final api = TronExamForumApi(
        _FakeCasClient(<String, String>{
          '/api/activities/2099717/topics':
              '{"topics":[{"id":1058060,"title":"受力图",'
              '"content":"<p>只画外力</p><p>符号方向协调</p>",'
              '"created_at":"2026-10-19T23:09:39Z","like_count":2,'
              '"created_by":{"id":1,"name":"周同学"},'
              '"replies":[{"content":"<p>同意</p>","created_at":"2026-10-20T01:00:00Z",'
              '"created_by":{"name":"李同学"}}]}]}',
        }),
      );

      final topics = await api.fetchForumTopics('2099717');

      expect(topics, hasLength(1));
      final topic = topics.single;
      expect(topic.id, '1058060');
      expect(topic.title, '受力图');
      expect(topic.content, '只画外力\n符号方向协调');
      expect(topic.author, '周同学');
      expect(topic.likeCount, 2);
      expect(topic.createdAt, isNotEmpty);
      expect(topic.replies, hasLength(1));
      expect(topic.replies.single.content, '同意');
      expect(topic.replies.single.author, '李同学');
    });

    test('空讨论返回空列表', () async {
      final api = TronExamForumApi(
        _FakeCasClient(<String, String>{
          '/api/activities/1/topics': '{"topics":[]}',
        }),
      );
      expect(await api.fetchForumTopics('1'), isEmpty);
    });
  });

  group('一网畅学发帖', () {
    test('先按活动查分类，再 POST /api/topics', () async {
      final fake = _FakeCasClient(<String, String>{
        '/api/courses/151598/topic-categories':
            '{"topic_categories":['
            '{"id":119150,"activity":{"id":2046218,"title":"挑战题"}},'
            '{"id":124073,"activity":{"id":2099717,"title":"受力图"}}]}',
      });

      await TronExamForumApi(fake).createTopic(
        courseId: '151598',
        activityId: '2099717',
        title: '我的标题',
        content: '我的正文',
      );

      expect(fake.posted, hasLength(1));
      expect(fake.posted.single['path'], '/api/topics');
      final data = fake.posted.single['data'] as Map<String, dynamic>;
      expect(data['category_id'], 124073);
      expect(data['title'], '我的标题');
      expect(data['content'], '我的正文');
    });

    test('找不到对应分类时抛错，不会乱发', () async {
      final fake = _FakeCasClient(<String, String>{
        '/api/courses/151598/topic-categories': '{"topic_categories":[]}',
      });

      await expectLater(
        TronExamForumApi(fake).createTopic(
          courseId: '151598',
          activityId: '2099717',
          title: 'a',
          content: 'b',
        ),
        throwsA(isA<Exception>()),
      );
      expect(fake.posted, isEmpty);
    });
  });
}
