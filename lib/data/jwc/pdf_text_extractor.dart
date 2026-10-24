import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 从 PDF 字节里抽取文字（针对教务生成的证明类 PDF，CID 字体 + ToUnicode）。
///
/// 步骤：
///   1. 解开所有 stream（多数是 FlateDecode）；
///   2. 解析 ToUnicode CMap（bfchar / bfrange），得到 glyph -> Unicode；
///   3. 解析内容流里的字符串（Tj / TJ），按 2 字节 CID 查表还原文字。
class PdfTextExtractor {
  const PdfTextExtractor._();

  static String extract(List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    final streams = _decodeStreams(data);
    final cmap = <int, String>{};
    for (final stream in streams) {
      _collectCMap(latin1.decode(stream, allowInvalid: true), cmap);
    }
    if (cmap.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (final stream in streams) {
      final text = latin1.decode(stream, allowInvalid: true);
      if (!text.contains('Tj') && !text.contains('TJ')) {
        continue;
      }
      buffer.write(_textFromContent(text, cmap));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  static List<Uint8List> _decodeStreams(Uint8List data) {
    final out = <Uint8List>[];
    var cursor = 0;
    while (true) {
      final start = _indexOf(data, const <int>[0x73, 0x74, 0x72, 0x65, 0x61, 0x6d], cursor); // stream
      if (start < 0) {
        break;
      }
      var bodyStart = start + 6;
      if (bodyStart < data.length && data[bodyStart] == 0x0d) {
        bodyStart++;
      }
      if (bodyStart < data.length && data[bodyStart] == 0x0a) {
        bodyStart++;
      }
      final end = _indexOf(
        data,
        const <int>[0x65, 0x6e, 0x64, 0x73, 0x74, 0x72, 0x65, 0x61, 0x6d], // endstream
        bodyStart,
      );
      if (end < 0) {
        break;
      }
      final raw = Uint8List.sublistView(data, bodyStart, end);
      try {
        out.add(Uint8List.fromList(const ZLibDecoder().decodeBytes(raw)));
      } catch (_) {
        out.add(raw);
      }
      cursor = end + 9;
    }
    return out;
  }

  static int _indexOf(Uint8List data, List<int> needle, int from) {
    final limit = data.length - needle.length;
    for (var i = from; i <= limit; i++) {
      var matched = true;
      for (var j = 0; j < needle.length; j++) {
        if (data[i + j] != needle[j]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return i;
      }
    }
    return -1;
  }

  static void _collectCMap(String text, Map<int, String> cmap) {
    if (!text.contains('beginbfchar') && !text.contains('beginbfrange')) {
      return;
    }
    for (final block in RegExp(r'beginbfchar([\s\S]*?)endbfchar').allMatches(text)) {
      for (final m
          in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>').allMatches(block.group(1) ?? '')) {
        cmap[int.parse(m.group(1)!, radix: 16)] = _utf16(m.group(2)!);
      }
    }
    for (final block in RegExp(r'beginbfrange([\s\S]*?)endbfrange').allMatches(text)) {
      for (final m in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')
          .allMatches(block.group(1) ?? '')) {
        final from = int.parse(m.group(1)!, radix: 16);
        final to = int.parse(m.group(2)!, radix: 16);
        final base = int.parse(m.group(3)!, radix: 16);
        for (var code = from; code <= to; code++) {
          cmap[code] = String.fromCharCode(base + (code - from));
        }
      }
    }
  }

  static String _utf16(String hex) {
    // ToUnicode 的值是 UTF-16BE，按 4 个十六进制位一个字符单元解析
    final units = <int>[];
    for (var i = 0; i + 3 < hex.length; i += 4) {
      units.add(int.parse(hex.substring(i, i + 4), radix: 16));
    }
    if (units.isEmpty) {
      return '';
    }
    try {
      return String.fromCharCodes(units);
    } catch (_) {
      return '';
    }
  }

  static String _textFromContent(String content, Map<int, String> cmap) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < content.length) {
      final ch = content[i];
      if (ch == '(') {
        final start = i + 1;
        var j = start;
        while (j < content.length) {
          if (content[j] == '\\') {
            j += 2;
            continue;
          }
          if (content[j] == ')') {
            break;
          }
          j++;
        }
        if (j >= content.length) {
          break;
        }
        final raw = _unescape(content.substring(start, j));
        buffer.write(_decodeCodes(raw, cmap));
        i = j + 1;
        continue;
      }
      if (ch == '<' && i + 1 < content.length && _isHex(content[i + 1])) {
        final end = content.indexOf('>', i + 1);
        if (end < 0) {
          break;
        }
        final hex = content.substring(i + 1, end).replaceAll(RegExp(r'\s'), '');
        final raw = <int>[];
        for (var k = 0; k + 1 < hex.length; k += 2) {
          raw.add(int.parse(hex.substring(k, k + 2), radix: 16));
        }
        buffer.write(_decodeCodes(raw, cmap));
        i = end + 1;
        continue;
      }
      i++;
    }
    return buffer.toString();
  }

  static bool _isHex(String ch) => RegExp(r'[0-9A-Fa-f]').hasMatch(ch);

  static List<int> _unescape(String source) {
    final out = <int>[];
    for (var i = 0; i < source.length; i++) {
      final code = source.codeUnitAt(i);
      if (code != 0x5c || i + 1 >= source.length) {
        out.add(code);
        continue;
      }
      final next = source[i + 1];
      switch (next) {
        case 'n':
          out.add(10);
          i++;
        case 'r':
          out.add(13);
          i++;
        case 't':
          out.add(9);
          i++;
        case 'b':
          out.add(8);
          i++;
        case 'f':
          out.add(12);
          i++;
        case '(':
          out.add(40);
          i++;
        case ')':
          out.add(41);
          i++;
        case '\\':
          out.add(92);
          i++;
        default:
          if (next.codeUnitAt(0) >= 0x30 && next.codeUnitAt(0) <= 0x37) {
            var k = 0;
            while (k < 3 && i + 1 + k < source.length) {
              final c = source.codeUnitAt(i + 1 + k);
              if (c < 0x30 || c > 0x37) {
                break;
              }
              k++;
            }
            out.add(int.parse(source.substring(i + 1, i + 1 + k), radix: 8));
            i += k;
          } else {
            out.add(next.codeUnitAt(0));
            i++;
          }
      }
    }
    return out;
  }

  static String _decodeCodes(List<int> raw, Map<int, String> cmap) {
    final out = StringBuffer();
    for (var i = 0; i + 1 < raw.length; i += 2) {
      final code = (raw[i] << 8) | raw[i + 1];
      out.write(cmap[code] ?? '');
    }
    return out.toString();
  }
}
