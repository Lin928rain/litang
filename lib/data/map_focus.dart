import 'package:flutter/foundation.dart';

import 'campus_places.dart';

/// 跨页面请求地图定位到某个地点。
class MapFocus {
  MapFocus._();

  static final ValueNotifier<CampusPlace?> target = ValueNotifier<CampusPlace?>(
    null,
  );

  static void focus(CampusPlace place) {
    target.value = place;
  }

  static void consume() {
    target.value = null;
  }
}
