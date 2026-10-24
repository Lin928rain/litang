import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/campus_places.dart';

void main() {
  test('官方地图地点数据', () {
    expect(kCampusPlaces.length, greaterThan(80));
    expect(kCampusPlaces.any((p) => p.name.contains('第一教学楼')), isTrue);
    for (final p in kCampusPlaces) {
      expect(p.anchor.dx, inInclusiveRange(0, 1));
      expect(p.anchor.dy, inInclusiveRange(0, 1));
    }
  });

  test('搜索地点', () {
    expect(searchCampusPlaces('第一教学楼').isNotEmpty, isTrue);
    expect(searchCampusPlaces(''), isEmpty);
    expect(searchCampusPlaces('不存在的地方'), isEmpty);
  });

  test('教室名解析到楼栋', () {
    expect(placeForRoom('三教106')?.name.contains('第三教学楼'), isTrue);
    expect(placeForRoom('一教146')?.name.contains('第一教学楼'), isTrue);
    expect(placeForRoom(''), isNull);
  });

  test('楼名别名归一化', () {
    expect(
      placeForRoom('卓越工程大楼118')?.name.contains('卓越楼'),
      isTrue,
    );
    expect(placeForRoom('综合A101')?.name.contains('综合楼'), isTrue);
    expect(
      placeForRoom('二公三')?.name.contains('第二学生公寓三号楼'),
      isTrue,
    );
    expect(
      searchCampusPlaces('一教').first.name,
      contains('第一教学楼'),
    );
    expect(
      searchCampusPlaces('二公三').first.name,
      contains('第二学生公寓三号楼'),
    );
  });
}
