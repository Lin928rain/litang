package com.example.project_usst

import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 学习通「网页登录」用：把内嵌 WebView 登录后的 cookie 交回 Dart 侧。
 *
 * webview_flutter 4.x 没有读 cookie 的 API，httpOnly 的会话 cookie 用
 * document.cookie 也拿不到，所以只能走一层平台通道读系统 CookieManager。
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "litang/web_cookies")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> {
                        val urls = call.argument<List<String>>("urls") ?: emptyList<String>()
                        // CookieManager 只能在主线程访问
                        Handler(Looper.getMainLooper()).post {
                            try {
                                val manager = CookieManager.getInstance()
                                manager.setAcceptCookie(true)
                                val out = HashMap<String, String>()
                                for (url in urls) {
                                    val raw = manager.getCookie(url)
                                    if (!raw.isNullOrEmpty()) {
                                        out[url] = raw
                                    }
                                }
                                result.success(out)
                            } catch (e: Exception) {
                                result.error("cookie_read_failed", e.message, null)
                            }
                        }
                    }

                    "clear" -> {
                        Handler(Looper.getMainLooper()).post {
                            try {
                                CookieManager.getInstance().removeAllCookies(null)
                                CookieManager.getInstance().flush()
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("cookie_clear_failed", e.message, null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
