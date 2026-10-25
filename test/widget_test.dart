import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/app_theme.dart';
import 'package:project_usst/data/models.dart';
import 'package:project_usst/data/notice_source.dart';
import 'package:project_usst/pages/home_page.dart';
import 'package:project_usst/pages/map_page.dart';
import 'package:project_usst/pages/profile_page.dart';
import 'package:project_usst/widgets/course_table.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

void main() {
  test('主题主色是上理红', () {
    expect(AppTheme.light().colorScheme.primary, AppColors.usstRed);
  });

  testWidgets('首页用演示数据源渲染通知流', (tester) async {
    await tester.pumpWidget(_wrap(const HomePage(source: DemoNoticeSource())));
    await tester.pumpAndSettle();

    expect(find.text('问点什么，比如“寒假哪天才开始”'), findsOneWidget);
    expect(find.text('关于调整校园上下课铃声的通知'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('点击搜索框弹出搜索中心', (tester) async {
    await tester.pumpWidget(_wrap(const HomePage(source: DemoNoticeSource())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('问点什么，比如“寒假哪天才开始”'));
    await tester.pumpAndSettle();

    expect(find.text('搜索中心'), findsOneWidget);
  });

  testWidgets('地图页可搜索楼栋并展示信息', (tester) async {
    await tester.pumpWidget(_wrap(const MapPage()));

    expect(find.text('校园地图'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '第一教学楼');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '第一教学楼'));
    await tester.pumpAndSettle();

    expect(find.text('第一教学楼'), findsWidgets);
    expect(find.text('军工路校区'), findsOneWidget);
  });

  testWidgets('我的页展示学业入口和课表区块', (tester) async {
    await tester.pumpWidget(_wrap(const ProfilePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('学业'), findsOneWidget);
    expect(find.textContaining('课表'), findsWidgets);
    // 空间入口：教室查询 / 学工一体化，旧的「我的课表」已移除
    expect(find.text('教室查询'), findsOneWidget);
    expect(find.text('学工一体化'), findsOneWidget);
    expect(find.text('我的课表'), findsNothing);
    // 个人信息卡：默认头像 + 昵称
    expect(find.text('🎓'), findsOneWidget);
    expect(find.text('同学'), findsOneWidget);
  });

  testWidgets('课表左栏显示每节起止时间', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Scaffold(
          body: SingleChildScrollView(
            child: CourseWeekTable(
              week: 3,
              courses: <Course>[
                Course(
                  name: '大学物理',
                  day: 2,
                  start: 2,
                  span: 3,
                  room: '三教106',
                  weeks: <int>[3, 4, 5],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('第1节'), findsOneWidget);
    expect(find.text('08:00-08:40'), findsOneWidget);
    expect(find.text('第13节'), findsOneWidget);
    expect(find.text('19:30-20:10'), findsOneWidget);
    // 课程块里只留课程名 / 教室 / 教师，不再显示上课时间
    expect(find.textContaining('09:45-11:55'), findsNothing);
    expect(find.text('大学物理'), findsOneWidget);
    expect(find.text('三教106'), findsOneWidget);
  });

  testWidgets('课表组件按节次渲染课程', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Scaffold(
          body: SingleChildScrollView(
            child: CourseWeekTable(
              week: 3,
              courses: <Course>[
                Course(
                  name: '高等数学',
                  day: 0,
                  start: 0,
                  span: 2,
                  room: '三教305',
                  weeks: <int>[3, 4],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('三教305'), findsOneWidget);
  });

  group('首页 + 真实产物', () {
    final file = File('tools/notice-sync/out/notices.json');
    if (!file.existsSync()) {
      test('跳过：本地没有 notices.json', () {}, skip: true);
      return;
    }

    testWidgets('7000+ 条真实数据不溢出，筛选条能用', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(HomePage(source: _FileSource(file))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 筛选条在（分类和「本院」都在）
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('竞赛'), findsWidgets);
      expect(find.textContaining('本院'), findsOneWidget);

      // 点「竞赛」后列表只剩竞赛（至少还能找到竞赛标签）
      await tester.tap(find.text('竞赛').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 往下滚几屏，确认懒加载不会崩
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  });
}

/// 用本地产物当数据源，避免 widget 测试里发网络请求。
class _FileSource implements NoticeSource {
  _FileSource(this.file);

  final File file;

  @override
  Future<NoticeFeed> fetch({bool force = false}) async =>
      RemoteNoticeSource.parseFeed(file.readAsStringSync())!;
}
