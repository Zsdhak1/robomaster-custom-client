/// Local loopback TCP server that serves the reassembled HEVC AnnexB stream.
///
/// Decoder players (media_kit / fvp) play from a URL, but we hold in-memory
/// AnnexB frames. This server binds `127.0.0.1:<port>`, accepts a single
/// client (the decoder) and writes each frame's bytes in arrival order — the
/// concatenation is a valid H.265 elementary stream.
///
/// Crucially, forwarding is GATED on a keyframe: a raw HEVC stream that begins
/// mid-GOP has no VPS/SPS/PPS parameter sets, so the decoder can never
/// initialise and drops the connection. We DROP frames until one carrying
/// VPS/SPS/PPS arrives, then stream continuously from that keyframe — this
/// mirrors the proven reference client's delayed-start strategy. We never
/// re-inject parameter sets mid-stream (that flushes the decoder's reference
/// buffer and corrupts decoding); the stream already carries them per IDR.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// HEVC NAL unit types for parameter sets (nal_unit_type values).
const int _nalVps = 32;
const int _nalSps = 33;
const int _nalPps = 34;

/// Max frames buffered while waiting for the first keyframe.
const int _maxPendingFrames = 30;

/// Serves a continuous AnnexB byte stream over a loopback TCP socket.
class AnnexbTcpServer {
  ServerSocket? _server;

  /// Connected decoder clients. Frames are broadcast to all of them.
  final List<Socket> _clients = [];

  /// Frames buffered until the first keyframe (VPS/SPS/PPS) is seen.
  ///
  /// These are pre-keyframe frames the decoder can't use; they are counted
  /// for diagnostics then DISCARDED when the gate opens so streaming starts
  /// cleanly at the keyframe.
  final List<Uint8List> _pending = [];

  /// Whether a keyframe has been seen and streaming has started.
  bool _started = false;

  /// Whether the server is currently bound and listening.
  bool get isRunning => _server != null;

  /// The port the server is bound to, or null when not running.
  int? get port => _server?.port;

  /// The URL a decoder should open to read the stream.
  ///
  /// Null when the server is not running.
  String? get streamUrl {
    final p = _server?.port;
    return p == null ? null : 'tcp://127.0.0.1:$p';
  }

  // --- Debug statistics ---

  /// Number of currently connected decoder clients.
  int get clientCount => _clients.length;

  /// Whether the keyframe gate has opened (a VPS/SPS/PPS frame was seen).
  bool get hasStarted => _started;

  /// Frames currently buffered waiting for the first keyframe.
  int get pendingCount => _pending.length;

  /// Total AnnexB frames forwarded to clients.
  int framesForwarded = 0;

  /// Total bytes forwarded to clients.
  int bytesForwarded = 0;

  /// Starts the loopback TCP server on an ephemeral port.
  Future<void> start() async {
    if (_server != null) return;

    framesForwarded = 0;
    bytesForwarded = 0;
    _started = false;
    _pending.clear();

    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);

    _server!.listen((socket) {
      _clients.add(socket);
      // Listen for client close/error so we clean up promptly.
      socket.listen(
        (_) {},
        onError: (_) => _removeClient(socket),
        onDone: () => _removeClient(socket),
        cancelOnError: true,
      );
      socket.done.whenComplete(() => _removeClient(socket));
    });
  }

  /// Feeds a reassembled AnnexB frame into the stream.
  ///
  /// Forwarding is gated on the first keyframe: pre-keyframe frames (which the
  /// decoder cannot use) are dropped, and streaming begins exactly at the
  /// first frame carrying VPS/SPS/PPS. This gives the decoder a clean IDR
  /// start and matches the proven reference client.
  ///
  /// We deliberately do NOT re-inject parameter sets before later frames:
  /// re-sending SPS/PPS mid-GOP flushes the decoder's reference-picture
  /// buffer, producing "Error constructing the frame RPS" and undecodable
  /// NALUs. The raw HEVC stream already carries VPS/SPS/PPS before every IDR.
  void feedFrame(Uint8List data) {
    if (!_started) {
      if (_containsParameterSet(data)) {
        // Gate opens: discard pre-keyframe junk, start clean at the keyframe.
        _started = true;
        _pending.clear();
        _writeToClients(data);
      } else {
        // Count frames seen while waiting (diagnostics only); they're junk.
        _pending.add(data);
        if (_pending.length > _maxPendingFrames) {
          _pending.removeAt(0);
        }
      }
      return;
    }
    _writeToClients(data);
  }

  /// Writes a frame to every connected client and updates counters.
  ///
  /// Uses [Socket.add] WITHOUT flush(): flush() returns a Future and, while it
  /// is pending, the IOSink is "bound" — a subsequent high-rate add() then
  /// throws `Bad state: StreamSink is bound to a stream` (a StateError, not an
  /// Exception, so it escapes the catch below and crashes the feed, dropping
  /// frames → "Could not find ref with POC"). add() already hands data to the
  /// OS asynchronously; on loopback it is delivered near-instantly.
  void _writeToClients(Uint8List data) {
    if (_clients.isEmpty) return;
    framesForwarded++;
    bytesForwarded += data.length;
    for (final client in List<Socket>.from(_clients)) {
      try {
        client.add(data);
      } on Exception catch (_) {
        // Client disconnected mid-write — clean up now.
        _removeClient(client);
      }
    }
  }

  /// Idempotent removal of a client socket.
  void _removeClient(Socket socket) {
    _clients.remove(socket);
    try {
      socket.destroy();
    } on Exception catch (_) {}
  }

  /// Scans an AnnexB buffer for a VPS/SPS/PPS NAL unit (HEVC).
  ///
  /// Walks start codes (00 00 01 / 00 00 00 01) and reads the 6-bit
  /// nal_unit_type from the first byte after each start code.
  bool _containsParameterSet(Uint8List d) {
    final n = d.length;
    var i = 0;
    while (i + 3 < n) {
      final isLong = d[i] == 0 && d[i + 1] == 0 && d[i + 2] == 0 && d[i + 3] == 1;
      final isShort = d[i] == 0 && d[i + 1] == 0 && d[i + 2] == 1;
      if (isLong || isShort) {
        final hdr = i + (isLong ? 4 : 3);
        if (hdr < n) {
          final nalType = (d[hdr] >> 1) & 0x3F;
          if (nalType == _nalVps || nalType == _nalSps || nalType == _nalPps) {
            return true;
          }
        }
        i = hdr;
      } else {
        i++;
      }
    }
    return false;
  }

  /// Stops the server and disconnects all clients.
  void stop() {
    for (final client in List<Socket>.from(_clients)) {
      client.destroy();
    }
    _clients.clear();
    _pending.clear();
    _started = false;
    _server?.close();
    _server = null;
  }

  /// Releases all resources. Same as [stop] for this server.
  void dispose() => stop();
}
