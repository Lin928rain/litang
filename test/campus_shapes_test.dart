import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/campus_places.dart';
import 'package:project_usst/data/campus_shapes.dart';

void main() {
  test('机械工程学院实验中心（二）两栋楼都能点中', () {
    final list = kCampusPlaces
        .where((p) => p.name == '机械工程学院实验中心（二）')
        .toList();
    expect(list.length, 2, reason: '应该有两个锚点');
    for (final place in list) {
      final hit = placeAt(place.anchor);
      expect(hit?.name, '机械工程学院实验中心（二）');
    }
  });

  test('第七学生宿舍与第七学生公寓区分', () {
    final dorm = kCampusPlaces.firstWhere((p) => p.name == '第七学生宿舍');
    expect(placeAt(dorm.anchor)?.name, '第七学生宿舍');
    final apartment = kCampusPlaces.firstWhere((p) => p.name == '第七学生公寓');
    expect(placeAt(apartment.anchor)?.name, '第七学生公寓');
  });

  test('轮廓数据非空且坐标合法', () {
    expect(kCampusShapes, isNotEmpty);
    for (final shape in kCampusShapes) {
      expect(shape.points.length, greaterThanOrEqualTo(3));
      for (final p in shape.points) {
        expect(p.dx, inInclusiveRange(0, 1));
        expect(p.dy, inInclusiveRange(0, 1));
      }
    }
  });
}
