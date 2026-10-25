import 'dart:convert';

import 'package:dio/dio.dart';

import '../auth/cas_client.dart';

/// 签到提交结果。
class SignResult {
  const SignResult({required this.success, this.message});

  final bool success;
  final String? message;
}

/// 进行中的一个签到。
class Rollcall {
  const Rollcall({
    required this.id,
    required this.courseName,
    required this.type,
    required this.timeText,
  });

  final String id;
  final String courseName;

  /// 原始类型，如 qr_rollcall / number_rollcall / radar_rollcall。
  final String type;
  final String timeText;

  bool get isNumberRollcall => type.toLowerCase().contains('number');

  bool get isRadarRollcall => type.toLowerCase().contains('radar');

  bool get isQrRollcall => type.toLowerCase().contains('qr');

  String get typeLabel {
    final t = type.toLowerCase();
    if (t.contains('qr')) {
      return '二维码签到';
    }
    if (t.contains('number') || t.contains('code')) {
      return '数字口令';
    }
    if (t.contains('radar')) {
      return '雷达点名';
    }
    if (t.contains('manual')) {
      return '手动点名';
    }
    if (t.contains('self')) {
      return '自主签到';
    }
    return '签到';
  }

  static Rollcall? fromJson(Map<String, dynamic> json) {
    final id =
        (json['id'] ??
                json['rollcall_id'] ??
                json['rollcallId'] ??
                json['uuid'] ??
                '')
            .toString();
    if (id.isEmpty) {
      return null;
    }
    String courseName = '';
    final course = json['course'];
    if (course is Map) {
      courseName = (course['name'] ?? course['course_name'] ?? '').toString();
    }
    courseName = courseName.isNotEmpty
        ? courseName
        : (json['course_name'] ??
                  json['courseName'] ??
                  json['kcmc'] ??
                  json['title'] ??
                  '')
              .toString();
    final type =
        (json['type'] ??
                json['source'] ??
                json['rollcall_type'] ??
                json['rollcallType'] ??
                '')
            .toString();
    final time =
        (json['created_at'] ??
                json['createdAt'] ??
                json['start_at'] ??
                json['begin_at'] ??
                json['started_at'] ??
                '')
            .toString();
    return Rollcall(
      id: id,
      courseName: courseName.isEmpty ? '未知课程' : courseName,
      type: type,
      timeText: _shortTime(time),
    );
  }

  static String _shortTime(String raw) {
    if (raw.isEmpty) {
      return '';
    }
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match != null) {
      return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
    }
    return raw;
  }
}

/// 把扫码得到的原始内容解析成签到请求体。
class QrPayload {
  const QrPayload._();

  static Map<String, dynamic> parse(String raw) {
    final text = raw.trim();
    if (text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {
        // fall through
      }
    }
    final uri = Uri.tryParse(text);
    if (uri != null && uri.queryParameters.isNotEmpty) {
      return Map<String, dynamic>.from(uri.queryParameters);
    }
    return <String, dynamic>{'code': text};
  }
}

/// 一网畅学签到接口。
class RollcallApi {
  RollcallApi(this.client);

  final CasClient client;

  static const String _radarUrl =
      'https://1906.usst.edu.cn/api/radar/rollcalls';

  /// 拉取「正在进行中」的签到（周末/无课时返回空列表）。
  Future<List<Rollcall>> fetchOngoing() async {
    final resp = await client.getApi(Uri.parse(_radarUrl));
    return parseOngoing(resp.data ?? '');
  }

  /// 数字口令签到。
  Future<SignResult> answerNumber(Rollcall rollcall, String code) async {
    return _put(
      '/api/rollcall/${rollcall.id}/answer_number_rollcall',
      <String, dynamic>{'code': code.trim()},
    );
  }

  /// 二维码签到：把扫到的原始内容解析成请求体提交。
  ///
  /// 二维码可能是 JSON、带参数的 URL 或纯口令，三种都兼容；
  /// 服务端拒绝时再用原始内容整体重试一次。
  Future<SignResult> answerQr(Rollcall rollcall, String raw) async {
    final payload = QrPayload.parse(raw);
    var result = await _put(
      '/api/rollcall/${rollcall.id}/answer_qr_rollcall',
      payload,
    );
    if (!result.success &&
        !(payload.length == 1 && payload.containsKey('code'))) {
      result = await _put(
        '/api/rollcall/${rollcall.id}/answer_qr_rollcall',
        <String, dynamic>{'code': raw.trim()},
      );
    }
    return result;
  }

  /// 雷达签到：上报当前位置。
  Future<SignResult> reportRadarPosition(
    Rollcall rollcall,
    double latitude,
    double longitude, {
    double? accuracy,
  }) async {
    final resp = await client.sendJson(
      Uri.parse(
        'https://1906.usst.edu.cn/api/rollcall/${rollcall.id}/position',
      ),
      method: 'PUT',
      data: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': ?accuracy,
      },
    );
    return _result(resp);
  }

  Future<SignResult> _put(String path, Map<String, dynamic> data) async {
    final resp = await client.sendJson(
      Uri.parse('https://1906.usst.edu.cn$path'),
      method: 'PUT',
      data: data,
    );
    return _result(resp);
  }

  SignResult _result(Response<String> resp) {
    final code = resp.statusCode ?? 0;
    final body = resp.data ?? '';
    if (code >= 200 && code < 300) {
      return const SignResult(success: true);
    }
    var message = '签到失败';
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      final msg = map['message'] ?? map['error'] ?? map['msg'];
      if (msg != null && msg.toString().isNotEmpty) {
        message = msg.toString();
      }
    } catch (_) {
      // ignore
    }
    return SignResult(success: false, message: message);
  }

  /// 解析 /api/radar/rollcalls 的响应。
  static List<Rollcall> parseOngoing(String raw) {
    if (!raw.trimLeft().startsWith('{')) {
      return const <Rollcall>[];
    }
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = (map['rollcalls'] as List<dynamic>? ?? <dynamic>[]);
    final out = <Rollcall>[];
    for (final item in list) {
      if (item is Map) {
        final rollcall = Rollcall.fromJson(item.cast<String, dynamic>());
        if (rollcall != null) {
          out.add(rollcall);
        }
      }
    }
    return out;
  }
}
