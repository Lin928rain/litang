import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'data/map_focus.dart';
import 'data/notice_source.dart';
import 'pages/home_page.dart';
import 'pages/life_page.dart';
import 'pages/map_page.dart';
import 'pages/forum_page.dart';
import 'pages/profile_page.dart';

void main() => runApp(const CampusApp());

class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '理堂',
      debugShowCheckedModeBanner: false,
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

  @override
  void initState() {
    super.initState();
    MapFocus.target.addListener(_onMapFocus);
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
    HomePage(source: JwcNoticeSource()),
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