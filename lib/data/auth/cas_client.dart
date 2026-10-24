import 'dart:convert';

import 'package:dio/dio.dart';

/// 登录失败，message 可直接展示给用户。
class CasLoginException implements Exception {
  CasLoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 把学校 `*.usst.edu.cn` 的 http 地址升级成 https。
///
/// CAS 链路里很多跳转先返回 http，再由页面 JS 跳到 https；
/// 直接按 302 请求 http 会卡在中间页，必须手动升级。
Uri upgradeCasUrl(Uri uri) {
  if (uri.scheme != 'http') {
    return uri;
  }
  final host = uri.host;
  if (host == 'usst.edu.cn' || host.endsWith('.usst.edu.cn')) {
    return uri.replace(scheme: 'https');
  }
  return uri;
}

/// 统一身份认证（CAS / authserver）登录页里的隐藏字段。
class CasTokens {
  const CasTokens({
    required this.lt,
    required this.execution,
    required this.eventId,
  });

  final String lt;
  final String execution;
  final String eventId;

  bool get isValid => lt.isNotEmpty && execution.isNotEmpty;

  /// 解析失败返回 null（例如页面结构变化或被风控拦截）。
  static CasTokens? parse(String html) {
    String? pick(String name) {
      final match =
          RegExp('name="$name"[^>]*value="([^"]*)"').firstMatch(html);
      return match?.group(1);
    }

    final lt = pick('lt');
    final execution = pick('execution');
    if (lt == null || execution == null) {
      return null;
    }
    return CasTokens(
      lt: lt,
      execution: execution,
      eventId: pick('_eventId') ?? 'submit',
    );
  }
}

/// 一条 cookie。domain 以 "." 开头表示可命中子域。
class CasCookie {
  const CasCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
  });

  final String name;
  final String value;
  final String domain;
  final String path;

  Map<String, String> toJson() => <String, String>{
        'name': name,
        'value': value,
        'domain': domain,
        'path': path,
      };

  static CasCookie fromJson(Map<String, dynamic> json) => CasCookie(
        name: json['name'] as String? ?? '',
        value: json['value'] as String? ?? '',
        domain: json['domain'] as String? ?? '',
        path: json['path'] as String? ?? '/',
      );

  bool matchesHost(String host) {
    if (domain.startsWith('.')) {
      final bare = domain.substring(1);
      return host == bare || host.endsWith(domain);
    }
    return host == domain;
  }

  bool matchesPath(String requestPath) {
    if (requestPath == path) {
      return true;
    }
    if (!requestPath.startsWith(path)) {
      return false;
    }
    return path.endsWith('/') || requestPath[path.length] == '/';
  }
}

/// 轻量 cookie jar：按域 / 路径匹配，够用且不引入额外依赖。
class CasCookieJar {
  final List<CasCookie> cookies = <CasCookie>[];

  void clear() => cookies.clear();

  void absorbSetCookie(Uri from, String line) {
    final parts = line.split(';');
    if (parts.isEmpty) {
      return;
    }
    final pair = parts.first;
    final eq = pair.indexOf('=');
    if (eq <= 0) {
      return;
    }
    final name = pair.substring(0, eq).trim();
    final value = pair.substring(eq + 1).trim();
    var domain = from.host;
    var path = _defaultPath(from.path);

    for (final raw in parts.skip(1)) {
      final attr = raw.trim();
      final lower = attr.toLowerCase();
      if (lower.startsWith('domain=')) {
        var d = attr.substring(7).trim();
        if (d.isNotEmpty && !d.startsWith('.')) {
          d = '.$d';
        }
        if (d.isNotEmpty) {
          domain = d;
        }
      } else if (lower.startsWith('path=')) {
        final p = attr.substring(5).trim();
        if (p.startsWith('/')) {
          path = p;
        }
      }
    }

    cookies.removeWhere(
      (c) => c.name == name && c.domain == domain && c.path == path,
    );
    cookies.add(CasCookie(name: name, value: value, domain: domain, path: path));
  }

  /// 取某个 host 下所有 cookie（WebView 注入用）。
  List<CasCookie> cookiesForHost(String host) =>
      cookies.where((c) => c.matchesHost(host)).toList();

  /// 生成请求头里的 Cookie 串；同一请求路径优先匹配更长的 path。
  String? headerFor(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    final matched = cookies
        .where((c) => c.matchesHost(uri.host) && c.matchesPath(path))
        .toList()
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
    final seen = <String>{};
    final out = <String>[];
    for (final c in matched) {
      if (!seen.add(c.name)) {
        continue;
      }
      out.add('${c.name}=${c.value}');
    }
    return out.isEmpty ? null : out.join('; ');
  }

  static String _defaultPath(String requestPath) {
    if (requestPath.isEmpty || !requestPath.startsWith('/')) {
      return '/';
    }
    final lastSlash = requestPath.lastIndexOf('/');
    return lastSlash <= 0 ? '/' : requestPath.substring(0, lastSlash);
  }
}

/// 复刻 usst-jwgl-client 的 CAS SSO 流程：
/// 入口 /sso/jziotlogin → ehall 适配器 → ids6 authserver → 回跳 jwglxt。
class CasClient {
  CasClient({Dio? dio, List<CasCookie> initialCookies = const <CasCookie>[]})
      : _dio = dio ?? _buildDio() {
    jar.cookies.addAll(initialCookies);
  }

  static const String entryUrl = 'https://jwgl.usst.edu.cn/sso/jziotlogin';
  static const String indexUrl =
      'https://jwgl.usst.edu.cn/jwglxt/xtgl/index_initMenu.html';

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final Dio _dio;
  final CasCookieJar jar = CasCookieJar();

  String? studentId;

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.plain,
      ),
    );
  }

  /// 登录。成功后 [jar] 里持有 jwglxt 会话 cookie。
  /// 网络抖动时自动重试一次（不会重复输密码）。
  Future<void> login(String username, String password) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _loginOnce(username, password);
        return;
      } on CasLoginException {
        rethrow;
      } on DioException {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    }
    throw CasLoginException('网络不稳定，登录失败，请稍后重试');
  }

  Future<void> _loginOnce(String username, String password) async {
    jar.clear();
    studentId = null;

    final entry = await _send(Uri.parse(entryUrl));
    final entryUri = entry.realUri;
    final entryHtml = entry.data ?? '';
    if (!entryUri.path.contains('authserver')) {
      throw CasLoginException('没有跳转到统一身份认证，请检查网络后重试');
    }
    final tokens = CasTokens.parse(entryHtml);
    if (tokens == null) {
      throw CasLoginException('统一身份认证页面解析失败，请稍后重试');
    }

    final result = await _send(
      entryUri,
      method: 'POST',
      form: <String, String>{
        'username': username.trim(),
        'password': password,
        'lt': tokens.lt,
        'dllt': 'userNamePasswordLogin',
        'execution': tokens.execution,
        '_eventId': tokens.eventId,
        'rmShown': '1',
      },
      referer: entryUri.toString(),
    );

    if (!await checkSession()) {
      final message = _extractError(result.data ?? '') ??
          _extractError(entryHtml) ??
          '登录失败，请检查学号和密码';
      throw CasLoginException(message);
    }
    studentId = username.trim();
  }

  /// 当前会话是否还能访问 jwglxt。
  Future<bool> checkSession() async {
    try {
      final resp = await _send(Uri.parse(indexUrl));
      final code = resp.statusCode ?? 0;
      final body = resp.data ?? '';
      return code == 200 &&
          !body.contains('用户登录') &&
          !body.contains('login_slogin');
    } catch (_) {
      return false;
    }
  }

  /// 用已保存的 cookie 静默进入 jwglxt：CASTGC 没过期时不需要再输密码。
  Future<bool> silentLogin() async {
    try {
      await _send(Uri.parse(entryUrl));
      return await checkSession();
    } catch (_) {
      return false;
    }
  }

  /// 下载二进制文件（PDF 等），同样处理 cookie 与 http->https 跳转。
  Future<List<int>> downloadBytes(Uri uri) async {
    var current = uri;
    for (var hop = 0; hop < 25; hop++) {
      final headers = <String, String>{
        'Accept': '*/*',
        'User-Agent': _userAgent,
      };
      final cookie = jar.headerFor(current);
      if (cookie != null) {
        headers['Cookie'] = cookie;
      }
      final resp = await _dio.requestUri<List<int>>(
        current,
        options: Options(
          method: 'GET',
          headers: headers,
          responseType: ResponseType.bytes,
        ),
      );
      _absorb(resp);
      final code = resp.statusCode ?? 0;
      final location = resp.headers.value('location');
      if (code >= 300 && code < 400 && location != null && location.isNotEmpty) {
        current = upgradeCasUrl(current.resolve(location));
        continue;
      }
      return resp.data ?? const <int>[];
    }
    return const <int>[];
  }

  /// 带登录态提交表单（POST，带 XHR 头），用于教务内部的 AJAX 接口。
  Future<Response<String>> postApi(
    Uri uri,
    Map<String, String> data, {
    String? referer,
    Map<String, String> extraHeaders = const <String, String>{},
  }) {
    return _send(
      uri,
      method: 'POST',
      form: data,
      referer: referer,
      accept: 'application/json, text/plain, */*',
      extraHeaders: <String, String>{
        'X-Requested-With': 'XMLHttpRequest',
        ...extraHeaders,
      },
    );
  }

  /// 带登录态提交 JSON（PUT/POST），用于一网畅学等第三方系统。
  Future<Response<String>> sendJson(
    Uri uri, {
    String method = 'POST',
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    return _send(
      uri,
      method: method,
      jsonBody: data,
      accept: 'application/json, text/plain, */*',
      extraHeaders: const <String, String>{
        'X-Requested-With': 'XMLHttpRequest',
      },
    );
  }

  /// 带登录态 GET 一个 JSON API（会带上 cookie，不设 jwgl 的 Referer）。
  Future<Response<String>> getApi(Uri uri) {
    return _send(
      uri,
      accept: 'application/json, text/plain, */*',
      extraHeaders: const <String, String>{'X-Requested-With': 'XMLHttpRequest'},
    );
  }

  /// 带登录态发请求（后续课表 / 成绩接口用）。
  Future<Response<String>> getJson(
    Uri uri, {
    Map<String, String>? data,
  }) {
    return _send(
      uri,
      method: data == null ? 'GET' : 'POST',
      form: data,
      referer: indexUrl,
      accept: 'application/json, text/javascript, */*; q=0.01',
      extraHeaders: const <String, String>{'X-Requested-With': 'XMLHttpRequest'},
    );
  }

  Future<Response<String>> _send(
    Uri url, {
    String method = 'GET',
    Map<String, String>? form,
    Object? jsonBody,
    String? referer,
    String accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    Map<String, String> extraHeaders = const <String, String>{},
  }) async {
    var current = url;
    var currentMethod = method;
    Map<String, String>? body = form;
    Object? currentJson = jsonBody;
    String? currentReferer = referer;
    Response<String>? last;

    for (var hop = 0; hop < 25; hop++) {
      final headers = <String, String>{
        'Accept': accept,
        'User-Agent': _userAgent,
        'Accept-Language': 'zh-CN,zh;q=0.9',
        ...extraHeaders,
      };
      final cookie = jar.headerFor(current);
      if (cookie != null) {
        headers['Cookie'] = cookie;
      }
      if (currentReferer != null) {
        headers['Referer'] = currentReferer;
      }

      final resp = await _dio.requestUri<String>(
        current,
        data: body ?? (currentJson == null ? null : jsonEncode(currentJson)),
        options: Options(
          method: currentMethod,
          headers: headers,
          contentType: body != null
              ? Headers.formUrlEncodedContentType
              : (currentJson == null ? null : Headers.jsonContentType),
        ),
      );
      _absorb(resp);
      last = resp;

      final code = resp.statusCode ?? 0;
      final location = resp.headers.value('location');
      if (code >= 300 && code < 400 && location != null && location.isNotEmpty) {
        current = upgradeCasUrl(current.resolve(location));
        currentMethod = 'GET';
        body = null;
        currentJson = null;
        currentReferer = current.toString();
        continue;
      }
      return resp;
    }
    return last!;
  }

  void _absorb(Response<dynamic> resp) {
    final raw = resp.headers.map['set-cookie'];
    if (raw == null || raw.isEmpty) {
      return;
    }
    final uri = resp.realUri;
    for (final line in raw) {
      jar.absorbSetCookie(uri, line);
    }
  }

  static String? _extractError(String html) {
    final match = RegExp('id="msg"[^>]*>([^<]*)<').firstMatch(html);
    final text = match?.group(1)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
