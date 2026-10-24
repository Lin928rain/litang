import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_theme.dart';
import '../data/auth/cas_client.dart';
import '../data/auth/jwgl_auth.dart';
import '../data/jwc/course_repository.dart';
import '../data/lms/rollcall_api.dart';
import '../data/lms/todo_api.dart';
import '../data/lms/tronclass_auth.dart';
import 'homework_page.dart';
import 'qr_scan_page.dart';
import 'simple_web.dart';

/// 生活：签到（一网畅学）+ 一网畅学入口 + 校园卡（占位）。
class LifePage extends StatefulWidget {
  const LifePage({super.key});

  @override
  State<LifePage> createState() => _LifePageState();
}

class _LifePageState extends State<LifePage> {
  bool _loading = false;
  String? _error;
  List<Rollcall> _rollcalls = const <Rollcall>[];
  List<LmsTodo> _todos = const <LmsTodo>[];
  List<LmsExam> _exams = const <LmsExam>[];
  String _currentTerm = '';
  String? _todosError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final snapshot = await CourseRepository.loadCache();
    _currentTerm = snapshot?.termLabel ?? '';
    // 生活页是启动时就存在的 tab，可能比「我的」页更早初始化，
    // 这里必须先恢复登录态，否则一网畅学接口会以未登录状态返回空。
    final auth = JwglAuth.instance;
    if (!auth.isLoggedIn) {
      await auth.restore();
    }
    final ok = await TronclassAuth.instance.ensureLoggedIn();
    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() {
        _error = '一网畅学登录失败，请先到「我的」登录教务系统';
      });
    }
    // 即使静默登录判定失败也尝试拉一次，避免误判导致整页空白
    await _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_loading) {
      return;
    }
    final auth = JwglAuth.instance;
    if (!auth.isLoggedIn) {
      if (mounted) {
        setState(() => _error = '未登录教务系统');
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final client = auth.client;
      if (client == null) {
        return;
      }
      var rollcalls = _rollcalls;
      var todos = _todos;
      var exams = _exams;
      var todosFetched = false;
      var examsFetched = false;
      try {
        rollcalls = await RollcallApi(client).fetchOngoing();
      } catch (_) {
        // 签到失败保留旧数据
      }
      String? todosError;
      try {
        final fetched = await LmsApi(client).fetchTodos();
        // 接口偶发返回空时保留旧数据，避免界面突然「全没了」
        if (fetched.isNotEmpty || _todos.isEmpty) {
          todos = fetched;
        }
        todosFetched = true;
      } catch (e) {
        todosError = '待办拉取失败：${e.toString().split("\n").first}';
      }
      try {
        final fetched = await LmsApi(client).fetchExams();
        if (fetched.isNotEmpty || _exams.isEmpty) {
          exams = fetched;
        }
        examsFetched = true;
      } catch (_) {
        // 考试安排失败保留旧数据
      }
      if (!todosFetched && !examsFetched && _todos.isEmpty && _exams.isEmpty) {
        // 两个都失败且无数据时给个提示
        if (mounted) {
          setState(() => _error = '学习数据拉取失败，请稍后重试');
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _rollcalls = rollcalls;
        _todos = todos;
        _exams = _filterExams(exams);
        _todosError = todosError;
        _error = null;
      });
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _error = '签到信息拉取失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  VoidCallback _signAction(Rollcall rollcall) {
    if (rollcall.isNumberRollcall) {
      return () => _signByNumber(rollcall);
    }
    if (rollcall.isRadarRollcall) {
      return () => _signByRadar(rollcall);
    }
    if (rollcall.isQrRollcall) {
      return () => _signByQr(rollcall);
    }
    return _openLms;
  }

  String _signLabel(Rollcall rollcall) {
    if (rollcall.isNumberRollcall) {
      return '输入口令';
    }
    if (rollcall.isRadarRollcall) {
      return '雷达签到';
    }
    if (rollcall.isQrRollcall) {
      return '扫码签到';
    }
    return '去签到';
  }

  /// 数字口令签到：输入老师给的口令后直接提交。
  Future<void> _signByNumber(Rollcall rollcall) async {
    final client = JwglAuth.instance.client;
    if (client == null) {
      _toast('请先登录教务系统');
      return;
    }
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${rollcall.courseName} · 数字口令'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '输入老师给出的签到口令',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('签到'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || input.isEmpty || !mounted) {
      return;
    }
    setState(() => _loading = true);
    var success = false;
    try {
      final result = await RollcallApi(client).answerNumber(rollcall, input);
      success = result.success;
      if (mounted) {
        _toast(result.success ? '签到成功' : (result.message ?? '签到失败'));
      }
    } catch (_) {
      if (mounted) {
        _toast('签到请求失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
    if (success) {
      await _refresh();
    }
  }

  /// 扫码签到：把扫到的二维码内容提交给一网畅学。
  Future<void> _signByQr(Rollcall rollcall) async {
    final client = JwglAuth.instance.client;
    if (client == null) {
      _toast('请先登录教务系统');
      return;
    }
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScanPage()),
    );
    if (raw == null || raw.isEmpty || !mounted) {
      return;
    }
    setState(() => _loading = true);
    var success = false;
    try {
      final result = await RollcallApi(client).answerQr(rollcall, raw);
      success = result.success;
      if (mounted) {
        _toast(result.success ? '签到成功' : (result.message ?? '签到失败'));
      }
    } catch (_) {
      if (mounted) {
        _toast('签到请求失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
    if (success) {
      await _refresh();
    }
  }

  /// 雷达签到：上报当前位置。
  Future<void> _signByRadar(Rollcall rollcall) async {
    final client = JwglAuth.instance.client;
    if (client == null) {
      _toast('请先登录教务系统');
      return;
    }
    setState(() => _loading = true);
    var success = false;
    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed) {
        _toast('雷达签到需要定位权限，请在系统设置里允许定位');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final result = await RollcallApi(client).reportRadarPosition(
        rollcall,
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
      );
      success = result.success;
      if (mounted) {
        _toast(result.success ? '雷达签到已上报' : (result.message ?? '雷达签到失败'));
      }
    } catch (_) {
      if (mounted) {
        _toast('定位失败，请到空旷处重试');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
    if (success) {
      await _refresh();
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _openTodo(LmsTodo todo) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => HomeworkPage(todo: todo)),
    );
  }

  Future<List<CasCookie>> _lmsCookies() async {
    final tronclass = await TronclassAuth.instance.loadCookies();
    final cas = JwglAuth.instance.client?.jar.cookies ?? const <CasCookie>[];
    final cookies = <CasCookie>[];
    final seen = <String>{};
    for (final cookie in <CasCookie>[...cas, ...tronclass]) {
      if (seen.add('${cookie.name}|${cookie.domain}|${cookie.path}')) {
        cookies.add(cookie);
      }
    }
    return cookies;
  }

  Future<void> _openLms() async {
    final cookies = await _lmsCookies();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SimpleWebPage(
          title: '一网畅学',
          url: 'https://1906.usst.edu.cn/user/index',
          cookies: cookies,
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  '生活学习',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: '刷新签到',
                    onPressed: () => _refresh(),
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _rollcallCard(),
            const SizedBox(height: 12),
            _todoCard(),
            const SizedBox(height: 12),
            _examCard(),
            const SizedBox(height: 12),
            _campusCard(),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _openLms,
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text(
                  '一网畅学网页版',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rollcallCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.how_to_reg_outlined,
                  size: 18, color: AppColors.usstRed),
              const SizedBox(width: 8),
              const Text(
                '进行中的签到',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_rollcalls.isNotEmpty)
                Text(
                  '${_rollcalls.length} 个',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _refresh(),
                  child: const Text('重试'),
                ),
              ],
            )
          else if (_rollcalls.isEmpty)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '暂无进行中的签到',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                SizedBox(height: 4),
                Text(
                  '老师发起签到后，点右上角刷新按钮即可看到',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            )
          else
            Column(
              children: <Widget>[
                for (final rollcall in _rollcalls) _rollcallTile(rollcall),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rollcallTile(Rollcall rollcall) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  rollcall.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${rollcall.typeLabel}'
                  '${rollcall.timeText.isEmpty ? '' : ' · ${rollcall.timeText}'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _signAction(rollcall),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.usstRed,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              _signLabel(rollcall),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _todoCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.assignment_outlined,
                  size: 18, color: AppColors.usstRed),
              const SizedBox(width: 8),
              const Text(
                '待办事项',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_todos.isNotEmpty)
                Text(
                  '${_todos.length} 个',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          if (_todosError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _todosError!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _refresh(),
                    child: const Text('重试', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else if (_todos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '暂无待办',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            SizedBox(
              height: 168,
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 8),
                itemCount: _todos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _todoTile(_todos[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _todoTile(LmsTodo todo) {
    final deadline = todo.deadline;
    final deadlineText = deadline == null ? '' : _formatDateTime(deadline);
    return GestureDetector(
      onTap: () => _openTodo(todo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                todo.typeLabel,
                style: const TextStyle(fontSize: 10, color: AppColors.usstRed),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    todo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      if (todo.courseName.isNotEmpty) todo.courseName,
                      if (deadlineText.isNotEmpty) '截止 $deadlineText',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _examCard() {
    if (_exams.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.event_note_outlined,
                  size: 18, color: AppColors.usstRed),
              const SizedBox(width: 8),
              const Text(
                '考试安排',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_exams.length} 场',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8),
              itemCount: _exams.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _examTile(_exams[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _examTile(LmsExam exam) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            exam.courseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            <String>[
              if (exam.termLabel.isNotEmpty) exam.termLabel,
              exam.timePending ? '时间待公布' : exam.timeText,
              if (exam.location.isNotEmpty) exam.location,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<LmsExam> _filterExams(List<LmsExam> exams) {
    if (exams.isEmpty) {
      return exams;
    }
    if (_currentTerm.isNotEmpty) {
      return exams.where((e) => e.termLabel == _currentTerm).toList();
    }
    final latest =
        exams.map((e) => e.termLabel).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    return exams.where((e) => e.termLabel == latest).toList();
  }

  String _formatDateTime(DateTime time) {
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$m-$d $h:$min';
  }

  Widget _campusCard() {
    return GestureDetector(
      onTap: () => _toast('校园卡功能还在逆向中，先用 WeLink 出示二维码'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.redTint,
              child: Icon(Icons.credit_card, color: AppColors.usstRed),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '校园卡',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '余额 / 出示二维码（暂未接入，占位）',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '敬请期待',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
