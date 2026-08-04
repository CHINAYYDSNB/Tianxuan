import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/data/ssh/terminal_output_buffer.dart';

void main() {
  group('TerminalOutputBuffer', () {
    test('add + flushNow 输出数据', () {
      final chunks = <Uint8List>[];
      final buf = TerminalOutputBuffer(chunks.add);
      buf.add([104, 105]);
      buf.flushNow();
      expect(chunks.length, 1);
      expect(chunks[0], [104, 105]);
      buf.dispose();
    });

    test('空 buffer flushNow 无输出', () {
      final chunks = <Uint8List>[];
      final buf = TerminalOutputBuffer(chunks.add);
      buf.flushNow();
      expect(chunks, isEmpty);
      buf.dispose();
    });

    test('超大输入触发 trim', () {
      final chunks = <Uint8List>[];
      final buf = TerminalOutputBuffer(chunks.add);
      // 超过 32KB
      final big = List<int>.generate(40 * 1024, (i) => i % 256);
      buf.add(big);
      buf.flushNow();
      expect(chunks, isNotEmpty);
      buf.dispose();
    });

    test('dispose 后无输出', () {
      final chunks = <Uint8List>[];
      final buf = TerminalOutputBuffer(chunks.add);
      buf.dispose();
      buf.add([1, 2]);
      buf.flushNow();
      expect(chunks, isEmpty);
    });

    test('定时 flush 自动输出', () async {
      final chunks = <Uint8List>[];
      final buf = TerminalOutputBuffer(chunks.add);
      buf.add([65, 66]);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(chunks, isNotEmpty);
      buf.dispose();
    });
  });
}
