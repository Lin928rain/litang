import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/chaoxing/chaoxing_course_detail.dart';

/// 真实页面结构（脱敏）：mArg 先被赋成空串，再赋真正的对象；
/// 附件元数据在 property 下，类型分 document / video 两族。
/// 第一个附件名里故意带花括号，用来验证花括号配对不会被字符串带偏。
const _cardsHtml = r'''
<!DOCTYPE html><html><body>
<div class="nullpage"><dd>暂无内容</dd></div>
<script>
(function(){
  mArg = "";

try{
    mArg = {"hiddenConfig":false,"isMirror":false,"attachments":[
      {"type":"document","aid":2426742618,"property":{"size":13809152,
       "hsize":"13.17 MB","module":"insertdoc","name":"第一章 {上} 课件.ppt",
       "type":".ppt","objectid":"aaa111","_jobid":"1632406260440591"}},
      {"type":"video","aid":2426742617,"property":{"size":120341672,
       "hsize":"114.77 MB","module":"insertvideo","name":"绪论视频.flv",
       "type":".flv","objectid":"bbb222"},"objectId":"bbb222"}
    ],"coursename":"某课程","knowledgename":"某章节"};
}catch(e){
}
</script>
</body></html>
''';

void main() {
  test('从 mArg 解析 document / video 两类附件', () {
    final items = ChaoxingCourseDetailApi.parseAttachments(_cardsHtml);

    expect(items, hasLength(2));

    expect(items[0].objectId, 'aaa111');
    expect(items[0].name, '第一章 {上} 课件.ppt');
    expect(items[0].size, 13809152);
    expect(items[0].isVideo, isFalse);

    expect(items[1].objectId, 'bbb222');
    expect(items[1].name, '绪论视频.flv');
    expect(items[1].size, 120341672);
    expect(items[1].isVideo, isTrue);
  });

  test('没有 mArg 的空壳页面返回空列表', () {
    const html = '<html><body><div class="nullpage">暂无内容</div></body></html>';
    expect(ChaoxingCourseDetailApi.parseAttachments(html), isEmpty);
    expect(ChaoxingCourseDetailApi.extractMarg(html), isNull);
  });

  test('attachments 为空数组时返回空列表', () {
    const html = '<script>mArg = {"attachments":[],"coursename":"x"};</script>';
    expect(ChaoxingCourseDetailApi.parseAttachments(html), isEmpty);
  });

  test('缺 objectid 或 name 的附件会被跳过', () {
    const html =
        '<script>mArg = {"attachments":['
        '{"type":"document","property":{"name":"没有id.pdf","size":1}},'
        '{"type":"document","property":{"objectid":"onlyid","size":2}}'
        ']};</script>';
    expect(ChaoxingCourseDetailApi.parseAttachments(html), isEmpty);
  });

  test('property 里缺 objectid 时回退到顶层 objectId', () {
    const html =
        '<script>mArg = {"attachments":[{"type":"video","objectId":"ccc333",'
        '"property":{"name":"视频.mp4","size":10}}]};</script>';
    final items = ChaoxingCourseDetailApi.parseAttachments(html);
    expect(items.single.objectId, 'ccc333');
    expect(items.single.isVideo, isTrue);
    expect(items.single.name, '视频.mp4');
  });

  test('mArg 不是合法 JSON 时返回空而不是抛异常', () {
    const html = r'<script>mArg = {bad json,,};</script>';
    expect(ChaoxingCourseDetailApi.parseAttachments(html), isEmpty);
  });
}
