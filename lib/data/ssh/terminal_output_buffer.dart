import 'dart:async';
import 'dart:typed_data';

/// Bounded output buffer for SSH terminal output.
/// Batches incoming bytes and flushes to xterm at ~60fps (16ms intervals).
/// Handles UTF-8 surrogate pair boundaries to avoid splitting multi-byte chars.
class TerminalOutputBuffer {
  static const _maxSize = 32 * 1024; // 32KB
  static const _flushInterval = Duration(milliseconds: 16);

  final void Function(Uint8List data) _onFlush;
  final _buffer = <int>[];
  Timer? _timer;
  bool _flushScheduled = false;

  TerminalOutputBuffer(this._onFlush);

  /// Add incoming SSH stdout bytes. Flush is scheduled on first add.
  void add(List<int> data) {
    if (_buffer.length + data.length > _maxSize) {
      _trimBuffer(data.length);
    }
    _buffer.addAll(data);
    _scheduleFlush();
  }

  /// Trim buffer to make room, ensuring we don't split UTF-8 at boundary.
  void _trimBuffer(int needed) {
    final removeCount = _buffer.length + needed - _maxSize;
    if (removeCount <= 0) return;
    var cut = removeCount;
    // Shift cut point forward if it would split a multi-byte UTF-8 character
    while (cut < _buffer.length && _isUtf8Continuation(_buffer[cut])) {
      cut++;
    }
    _buffer.removeRange(0, cut);
  }

  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    _timer ??= Timer(_flushInterval, _flush);
  }

  void _flush() {
    _timer = null;
    _flushScheduled = false;
    if (_buffer.isEmpty) return;

    // Ensure we don't flush mid-character at the end boundary
    final len = _buffer.length;
    var keep = 0;
    if (len > 0 && _isUtf8Start(_buffer.last)) {
      // Last byte starts a multi-byte sequence — keep it for next flush
      keep = 1;
      if (len >= 2) {
        final seqLen = _utf8SeqLen(_buffer[len - 1]);
        for (var i = 1; i < seqLen && len - i > 0; i++) {
          if (!_isUtf8Continuation(_buffer[len - 1 - i])) break;
          keep = i + 1;
        }
      }
    }

    final flushLen = _buffer.length - keep;
    if (flushLen > 0) {
      final chunk = Uint8List.fromList(_buffer.sublist(0, flushLen));
      _buffer.removeRange(0, flushLen);
      _onFlush(chunk);
    }
  }

  void flushNow() {
    _timer?.cancel();
    _timer = null;
    _flushScheduled = false;
    if (_buffer.isEmpty) return;
    final chunk = Uint8List.fromList(_buffer);
    _buffer.clear();
    _onFlush(chunk);
  }

  void dispose() {
    _timer?.cancel();
    _buffer.clear();
  }

  // ─── UTF-8 helpers ───

  /// Check if byte is a UTF-8 continuation byte (10xxxxxx).
  static bool _isUtf8Continuation(int byte) => (byte & 0xC0) == 0x80;

  /// Check if byte starts a multi-byte UTF-8 sequence (11xxxxxx).
  static bool _isUtf8Start(int byte) => (byte & 0xC0) == 0xC0;

  /// Get expected UTF-8 sequence length from start byte.
  static int _utf8SeqLen(int startByte) {
    if ((startByte & 0x80) == 0) return 1;
    if ((startByte & 0xE0) == 0xC0) return 2;
    if ((startByte & 0xF0) == 0xE0) return 3;
    if ((startByte & 0xF8) == 0xF0) return 4;
    return 1;
  }
}
