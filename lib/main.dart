import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'data/calendar/calendar_service.dart';
import 'data/map_focus.dart';
import 'data/notice_source.dart';
import 'pages/home_page.dart';
import 'pages/update_page.dart';
import 'services/update_service.dart';
import 'pages/life_page.dart';
import 'pages/map_page.dart';
import 'pages/forum_page.dart';
import 'pages/profile_page.dart';

/// 全局导航 key（保留给以后的深链用）。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CalendarService.instance.load();
  runApp(const CampusApp());
}

class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '理堂',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light(),
      home: const RootScaffold(),
    );
  }
}

/// 底部五 Tab 骨架：首页 / 地图 / 生活 / 论坛 / 我的
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  static bool _checkedUpdate = false;

  @override
  void initState() {
    super.initState();
    MapFocus.target.addListener(_onMapFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_checkedUpdate || !mounted) return;
      _checkedUpdate = true;
      final info = await UpdateService.check();
      if (info != null && mounted) {
        await showUpdateDialog(context, info, startup: true);
      }
    });
  }

  @override
  void dispose() {
    MapFocus.target.removeListener(_onMapFocus);
    super.dispose();
  }

  void _onMapFocus() {
    if (MapFocus.target.value != null && _index != 1) {
      setState(() => _index = 1);
    }
  }

  /// 页面只构建一次；首页在这里注入真实数据源，页面本身仍可单独注入演示数据。
  static final List<Widget> _pages = [
    HomePage(source: RemoteNoticeSource()),
    const MapPage(),
    const LifePage(),
    const ForumPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '地图',
          ),
          NavigationDestination(
            icon: Image.asset(
              'assets/emblem.webp',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.high,
            ),
            selectedIcon: Image.asset(
              'assets/emblem.webp',
              width: 32,
              height: 32,
              filterQuality: FilterQuality.high,
            ),
            label: '理堂',
            tooltip: '理堂',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: '论坛',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
