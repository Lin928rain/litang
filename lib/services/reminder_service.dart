import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/auth/cas_client.dart';
import '../data/auth/jwgl_auth.dart';
import '../data/chaoxing/chaoxing_auth.dart';
import '../data/chaoxing/chaoxing_client.dart';
import '../data/lms/homework_api.dart';
import '../data/lms/todo_api.dart';
import '../data/lms/tronclass_auth.dart';
import 'reminder_plan.dart';

/// 作业 DDL 的本地提醒（考试不提醒，考试时间大家自己会盯）。
///
/// 两个来源：
///   - 一网畅学 `/api/todos`：绝对截止时间；
///   - 学习通作业列表：只有「剩余 91 小时 40 分钟」这种相对文本，
///     按拉取时刻换算成绝对时间。
///
/// 每个作业按「截止前 1 天 / 前 2 小时」各排一个通知，通知 id 由作业 key
/// 稳定哈希得到，所以重复同步只会覆盖、不会堆叠；已提交或已消失的作业
/// 会把旧的提醒取消掉。
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const String _channelId = 'litang_deadline';
  static const String _channelName = '作业截止提醒';
  static const String _channelDesc = '作业快截止时提醒';

  static const String _tronPrefix = 'tron:';
  static const String _cxPrefix = 'cx:';

  static const List<Duration> _offsets = <Duration>[
    Duration(days: 1),
    Duration(hours: 2),
  ];

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _unavailable = false;
  Set<String>? _scheduledKeys;
  Map<int, PlannedReminder>? _iosPlan;
  final Map<int, String> _iosSubmitted = <int, String>{};
  Future<void> _iosPlanOperations = Future<void>.value();

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // ---------------------------------------------------------------- 初始化

  Future<bool> _ensureReady() async {
    if (_initialized) return true;
    if (_unavailable || !_supported) return false;
    try {
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      }
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) =>
            _handleTap(response.payload),
      );
      // App 是被点通知拉起来的情况：这次回调不会走上面，要单独取一次
      try {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          _handleTap(launch?.notificationResponse?.payload);
        }
      } catch (_) {
        // 忽略
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      try {
        await android?.requestNotificationsPermission();
        await android?.requestExactAlarmsPermission();
      } catch (_) {
        // 权限被拒也能用非精确闹钟兜底
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true, badge: true);
        // 从磁盘恢复所有来源，补足先前因容量限制而没有提交给系统的提醒。
        try {
          await _updateIosPlan((_) {});
        } catch (_) {
          // 缓存或某条计划失败不应禁用整个通知服务；下一次同步会重试。
        }
      }
      _initialized = true;
      return true;
    } catch (_) {
      _unavailable = true;
      return false;
    }
  }

  /// 用户点了通知：主界面监听这个，跳转到对应作业详情。
  static final ValueNotifier<Map<String, dynamic>?> pendingTarget =
      ValueNotifier<Map<String, dynamic>?>(null);

  static const String _offPrefix = 'off:';

  static String _offKey(String key) => '$_offPrefix$key';

  void _handleTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic>) {
        pendingTarget.value = map;
      }
    } catch (_) {
      // 老格式的 payload（key|时间）忽略即可
    }
  }

  Map<String, dynamic> _todoPayload(LmsTodo todo) => <String, dynamic>{
    'kind': 'tron',
    'id': todo.id,
    'courseId': todo.courseId,
    'title': todo.title,
    'courseName': todo.courseName,
  };

  Map<String, dynamic> _workPayload(ChaoxingWork work) => <String, dynamic>{
    'kind': 'cx',
    'workId': work.workId,
    'title': work.title,
    'courseName': work.courseName,
    'statusText': work.statusText,
    'deadline': work.deadline,
    'expired': work.expired,
    'taskUrl': work.taskUrl,
  };

  // ------------------------------------------------------------ 一网畅学作业

  /// [submittedActivityIds] 是「我已经交过的活动 id」，这些不再提醒。
  /// 查「我已经交过哪些作业」：按课程拉提交记录，取 activity_id。
  Future<Set<int>> fetchSubmittedIds(
    CasClient client,
    List<LmsTodo> todos,
  ) async {
    final ids = <int>{};
    try {
      final courseIds = todos
          .map((t) => t.courseId)
          .where((id) => id > 0)
          .toSet();
      for (final courseId in courseIds) {
        final list = await HomeworkApi(client).fetchSubmissions(courseId);
        ids.addAll(list.map((s) => s.activityId));
      }
    } catch (_) {
      // 查不到就当不知道，宁可多提醒一次
    }
    return ids;
  }

  /// 启动时在后台静默同步一次（登录 → 拉作业 → 排提醒）。
  ///
  /// 只要 App 被打开过就会排上，不依赖用户切到「生活」页；
  /// 6 小时内重复启动不会重复跑，避免每次开 App 都打一堆请求。
  Future<void> syncInBackground({bool force = false}) async {
    if (!_supported) return;
    if (!force && await _syncedRecently()) return;
    try {
      final jwgl = JwglAuth.instance;
      if (!jwgl.isLoggedIn) {
        await jwgl.restore();
      }
      if (jwgl.client == null) return;
      await TronclassAuth.instance.ensureLoggedIn();
      final client = jwgl.client;
      if (client == null) return;

      // 一网畅学作业
      final todos = await LmsApi(client).fetchTodos();
      final submitted = await fetchSubmittedIds(client, todos);
      await syncHomework(todos: todos, submittedActivityIds: submitted);

      // 学习通作业：只有登录过才拉，失败不影响上面的结果
      try {
        final cx = ChaoxingAuth.instance;
        if (!cx.isLoggedIn) {
          await cx.restore();
        }
        if (await cx.ensureSession()) {
          final cxClient = cx.client;
          if (cxClient != null) {
            final courses = await cxClient.fetchCourses();
            final works = await cxClient.fetchWorks(courses);
            if (works.isNotEmpty) {
              await syncChaoxingWorks(works);
            }
          }
        }
      } catch (_) {
        // 学习通那侧失败就算了
      }

      await _markSynced();
    } catch (_) {
      // 后台同步失败不能影响 App
    }
  }

  Future<void> syncHomework({
    required List<LmsTodo> todos,
    Set<int> submittedActivityIds = const <int>{},
  }) async {
    if (!await _ensureReady()) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      final wallClock = DateTime.now();
      final keys = Set<String>.of(await _loadKeys());
      final fresh = <String>{};

      for (final todo in todos) {
        if (submittedActivityIds.contains(todo.id)) continue;
        final deadline = todo.deadline;
        if (deadline == null || !deadline.isAfter(wallClock)) continue;
        final key = '$_tronPrefix${todo.id}';
        // 用户在作业详情页手动关掉的，跳过（也就不会排新的）
        if (keys.contains(_offKey(key))) continue;
        fresh.add(key);
        await _schedule(
          key: key,
          deadline: deadline,
          title: '作业快截止了',
          body: '${todo.courseName}\n${todo.title}',
          now: now,
          extraPayload: _todoPayload(todo),
        );
      }

      await _reconcile(keys, fresh, _tronPrefix);
    } catch (_) {
      // 提醒失败不能影响页面
    }
  }

  // -------------------------------------------------------------- 学习通作业

  /// 学习通作业只有相对时间（剩余 X 小时 Y 分钟），按当前时刻算成绝对时间。
  /// 每次拉到作业列表都会重算，所以只要偶尔打开一次 App，计划就是准的。
  Future<void> syncChaoxingWorks(List<ChaoxingWork> works) async {
    if (!await _ensureReady()) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      final wallClock = DateTime.now();
      final keys = Set<String>.of(await _loadKeys());
      final fresh = <String>{};

      for (final work in works) {
        // 已交 / 已批阅 / 已截止都不提醒
        if (work.finished || work.expired) continue;
        final remaining = parseRemaining(work.deadline);
        if (remaining == null || remaining <= Duration.zero) continue;
        final key = '$_cxPrefix${work.workId}';
        if (keys.contains(_offKey(key))) continue;
        fresh.add(key);
        await _schedule(
          key: key,
          deadline: wallClock.add(remaining),
          title: '学习通作业快截止了',
          body: '${work.courseName}\n${work.title}',
          now: now,
          extraPayload: _workPayload(work),
        );
      }

      await _reconcile(keys, fresh, _cxPrefix);
    } catch (_) {
      // 忽略
    }
  }

  // ------------------------------------------------------ 单条开关 / 手动排

  /// 这个作业是否开着提醒（默认开）。
  Future<bool> isReminderEnabled(String key) async {
    final keys = await _loadKeys();
    return !keys.contains(_offKey(key));
  }

  /// 打开 / 关掉某个作业的提醒。
  Future<void> setReminderEnabled(String key, bool enabled) async {
    final keys = Set<String>.of(await _loadKeys());
    if (enabled) {
      keys.remove(_offKey(key));
    } else {
      await _ensureReady();
      await _cancelKey(key);
      keys.add(_offKey(key));
    }
    await _saveKeys(keys);
  }

  /// 单独排一个一网畅学作业（详情页打开开关时用，不影响其它作业）。
  Future<void> scheduleHomeworkOne(LmsTodo todo) async {
    if (!await _ensureReady()) return;
    final deadline = todo.deadline;
    if (deadline == null || !deadline.isAfter(DateTime.now())) return;
    final key = '$_tronPrefix${todo.id}';
    await _schedule(
      key: key,
      deadline: deadline,
      title: '作业快截止了',
      body: '${todo.courseName}\n${todo.title}',
      now: tz.TZDateTime.now(tz.local),
      extraPayload: _todoPayload(todo),
    );
    final keys = Set<String>.of(await _loadKeys())..add(key);
    await _saveKeys(keys);
  }

  /// 单独排一个学习通作业。
  Future<void> scheduleChaoxingOne(ChaoxingWork work) async {
    if (!await _ensureReady()) return;
    final remaining = parseRemaining(work.deadline);
    if (remaining == null || remaining <= Duration.zero) return;
    final key = '$_cxPrefix${work.workId}';
    await _schedule(
      key: key,
      deadline: DateTime.now().add(remaining),
      title: '学习通作业快截止了',
      body: '${work.courseName}\n${work.title}',
      now: tz.TZDateTime.now(tz.local),
      extraPayload: _workPayload(work),
    );
    final keys = Set<String>.of(await _loadKeys())..add(key);
    await _saveKeys(keys);
  }

  // ------------------------------------------------------------------ 内部

  /// 把某一来源里「这次不在列表里」的旧提醒取消掉，再记下新的 key 集合。
  Future<void> _reconcile(
    Set<String> keys,
    Set<String> fresh,
    String prefix,
  ) async {
    for (final key
        in keys
            .where((k) => k.startsWith(prefix) && !fresh.contains(k))
            .toList()) {
      await _cancelKey(key);
      keys.remove(key);
    }
    keys.addAll(fresh);
    await _saveKeys(keys);
  }

  Future<void> _schedule({
    required String key,
    required DateTime deadline,
    required String title,
    required String body,
    required tz.TZDateTime now,
    Map<String, dynamic> extraPayload = const <String, dynamic>{},
  }) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final payload = jsonEncode(<String, dynamic>{
        'key': key,
        ...extraPayload,
      });
      await _updateIosPlan((plan) {
        plan.removeWhere((_, entry) => entry.key == key);
        for (var slot = 0; slot < _offsets.length; slot++) {
          final fireAt = deadline.subtract(_offsets[slot]);
          if (!fireAt.isAfter(now)) continue;
          final id = _idFor(key, slot);
          plan[id] = PlannedReminder(
            id: id,
            key: key,
            fireAt: fireAt,
            title: title,
            body: body,
            payload: payload,
          );
        }
      });
      return;
    }
    for (var slot = 0; slot < _offsets.length; slot++) {
      final id = _idFor(key, slot);
      final fireAt = tz.TZDateTime.from(
        deadline.subtract(_offsets[slot]),
        tz.local,
      );
      if (!fireAt.isAfter(now)) {
        // 这个提前量已经过了，清掉可能残留的旧计划
        try {
          await _plugin.cancel(id: id);
        } catch (_) {}
        continue;
      }
      final details = _details();
      final payload = jsonEncode(<String, dynamic>{
        'key': key,
        ...extraPayload,
      });
      try {
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: fireAt,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          title: title,
          body: body,
          payload: payload,
        );
      } catch (_) {
        // 精确闹钟被系统禁用时降级成非精确
        try {
          await _plugin.zonedSchedule(
            id: id,
            scheduledDate: fireAt,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: title,
            body: body,
            payload: payload,
          );
        } catch (_) {
          // 排不上就算了，下一次同步还会再试
        }
      }
    }
  }

  Future<void> _cancelKey(String key) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _updateIosPlan((plan) {
        plan.removeWhere((_, entry) => entry.key == key);
      });
      return;
    }
    for (var slot = 0; slot < _offsets.length; slot++) {
      try {
        await _plugin.cancel(id: _idFor(key, slot));
      } catch (_) {}
    }
  }

  /// 串行合并两个来源的计划；只向 iOS 提交最近的最多 60 条，预留系统容量。
  Future<void> _updateIosPlan(void Function(Map<int, PlannedReminder>) update) {
    final operation = _iosPlanOperations.catchError((Object _) {}).then((
      _,
    ) async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ios_reminder_plan.json');
      var plan = _iosPlan;
      if (plan == null) {
        plan = <int, PlannedReminder>{};
        if (await file.exists()) {
          try {
            final records = jsonDecode(await file.readAsString());
            if (records is List) {
              for (final raw in records) {
                try {
                  final entry = PlannedReminder.fromJson(
                    Map<String, dynamic>.from(raw as Map),
                  );
                  plan[entry.id] = entry;
                } catch (_) {
                  // 单条旧记录损坏不能阻断其它提醒。
                }
              }
            }
          } catch (_) {
            // 文件损坏时从下次同步重建。
          }
        }
        _iosPlan = plan;
      }
      update(plan);
      final now = DateTime.now();
      plan.removeWhere((_, entry) => !entry.fireAt.isAfter(now));
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode(plan.values.map((e) => e.toJson()).toList()),
      );
      await temp.rename(file.path);

      final pending = await _plugin.pendingNotificationRequests();
      bool managed(PendingNotificationRequest request) {
        try {
          final key = (jsonDecode(request.payload ?? '') as Map)['key'];
          return key is String &&
              (key.startsWith(_tronPrefix) || key.startsWith(_cxPrefix));
        } catch (_) {
          return false;
        }
      }

      final others = pending.where((request) => !managed(request)).length;
      final chosen = nearestReminders(
        plan.values,
        now: now,
        limit: 60 - others,
      );
      final chosenIds = chosen.map((entry) => entry.id).toSet();
      for (final request in pending.where(managed)) {
        if (!chosenIds.contains(request.id)) {
          await _plugin.cancel(id: request.id);
        }
      }
      _iosSubmitted.removeWhere((id, _) => !chosenIds.contains(id));
      final pendingIds = pending.map((request) => request.id).toSet();
      for (final entry in chosen) {
        final signature = jsonEncode(entry.toJson());
        if (pendingIds.contains(entry.id) &&
            _iosSubmitted[entry.id] == signature) {
          continue;
        }
        await _plugin.zonedSchedule(
          id: entry.id,
          scheduledDate: tz.TZDateTime.from(entry.fireAt, tz.local),
          notificationDetails: _details(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          title: entry.title,
          body: entry.body,
          payload: entry.payload,
        );
        _iosSubmitted[entry.id] = signature;
      }
    });
    _iosPlanOperations = operation;
    return operation;
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  /// 通知 id 必须跨进程稳定，所以不用 String.hashCode（不保证跨运行一致）。
  static int _idFor(String key, int slot) {
    var hash = 0x811c9dc5;
    for (final unit in '$key#$slot'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  // -------------------------------------------------------------- 计划持久化

  Future<File?> _stateFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/reminder_state.json');
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> _loadKeys() async {
    final cached = _scheduledKeys;
    if (cached != null) return cached;
    final keys = <String>{};
    try {
      final file = await _stateFile();
      if (file != null && await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is List) keys.addAll(raw.whereType<String>());
      }
    } catch (_) {
      // 读不出来就当没有
    }
    _scheduledKeys = keys;
    return keys;
  }

  Future<void> _saveKeys(Set<String> keys) async {
    _scheduledKeys = keys;
    try {
      final file = await _stateFile();
      await file?.writeAsString(jsonEncode(keys.toList()));
    } catch (_) {
      // 存不下来只影响下次去重，不影响本次提醒
    }
  }

  /// 后台同步的最小间隔：太频繁启动没必要每次都打一遍接口。
  static const Duration _minSyncInterval = Duration(hours: 6);

  Future<File?> _syncStampFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/reminder_synced_at.txt');
    } catch (_) {
      return null;
    }
  }

  Future<bool> _syncedRecently() async {
    try {
      final file = await _syncStampFile();
      if (file == null || !await file.exists()) return false;
      final at = DateTime.tryParse((await file.readAsString()).trim());
      if (at == null) return false;
      return DateTime.now().difference(at) < _minSyncInterval;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markSynced() async {
    try {
      final file = await _syncStampFile();
      await file?.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {
      // 忽略
    }
  }

  // ------------------------------------------------------------------ 解析

  /// 解析学习通的「剩余 91 小时 40 分钟」这类文本。
  /// 认 天 / 小时 / 分钟，任意组合；认不出来返回 null。
  static Duration? parseRemaining(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final day = RegExp(r'(\d+)\s*天').firstMatch(text);
    final hour = RegExp(r'(\d+)\s*小时').firstMatch(text);
    final minute = RegExp(r'(\d+)\s*分钟').firstMatch(text);
    if (day == null && hour == null && minute == null) return null;
    final days = int.tryParse(day?.group(1) ?? '') ?? 0;
    final hours = int.tryParse(hour?.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(minute?.group(1) ?? '') ?? 0;
    return Duration(days: days, hours: hours, minutes: minutes);
  }
}
