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

import '../core/utils/byte_data_reader.dart';

/// Max frames buffered while waiting for the first keyframe.
const int _maxPendingFrames = 30;

/// Signature of a function that reports whether an AnnexB buffer carries the
/// codec parameter sets that gate the start of decoding.
///
/// The default ([hevcHasParameterSet]) is HEVC; the custom video line injects
/// an H.264 detector so the two lines never share NAL parsing.
typedef ParameterSetDetector = bool Function(Uint8List data);

/// Serves a continuous AnnexB byte stream over a loopback TCP socket.
class AnnexbTcpServer {
  /// Creates a server whose keyframe gate uses [parameterSetDetector].
  ///
  /// Defaults to HEVC detection so the official UDP 3334 video line keeps its
  /// existing behaviour unchanged. The custom 0x0310 H.264 line passes
  /// [h264HasParameterSet] instead.
  AnnexbTcpServer({ParameterSetDetector? parameterSetDetector})
      : _detectParameterSet = parameterSetDetector ?? hevcHasParameterSet;

  /// Detector deciding whether a frame opens the keyframe gate.
  final ParameterSetDetector _detectParameterSet;

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

  /// The most recent parameter-set keyframe (the frame carrying VPS/SPS/PPS +
  /// IDR that opened the gate; refreshed on every later keyframe).
  ///
  /// Replayed to every decoder that connects AFTER the gate opened — which is
  /// the normal case, because the player attaches asynchronously, only once the
  /// bridge URL is known, by which time the bridge has usually already forwarded
  /// the SPS/PPS+IDR to an empty client list and lost it.
  ///
  /// This is what unblocks fvp/mdk specifically: its `updateTexture()` cannot
  /// create the render texture until it knows the video size, which lives in the
  /// SPS. Reading the SPS via a large probe and then seeking back to start fails
  /// on a non-seekable live TCP stream, so the keyframe is dropped and the
  /// decoder shows a white screen. Putting the keyframe at the very start of
  /// each client's stream gives the decoder its size and a decodable IDR
  /// immediately, with no probe/seek and no up-to-a-full-GOP wait. Null until
  /// the gate opens.
  Uint8List? _keyframe;

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
    _keyframe = null;
    _pending.clear();

    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);

    _server!.listen((socket) {
      _clients.add(socket);
      // Prime a late-joining decoder with the cached keyframe so it starts from
      // a clean IDR (parameter sets present) instead of mid-GOP with no
      // reference frame. No-op until the gate has opened; clients that connect
      // first get the keyframe live as usual.
      _replayKeyframe(socket);
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
      if (_detectParameterSet(data)) {
        // Gate opens: discard pre-keyframe junk, start clean at the keyframe.
        _started = true;
        _pending.clear();
        _keyframe = data;
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
    // Keep the cached keyframe fresh so a client connecting later is primed
    // with the most recent parameter sets, not the very first ones.
    if (_detectParameterSet(data)) {
      _keyframe = data;
    }
    _writeToClients(data);
  }

  /// Sends the cached keyframe to a freshly connected [socket] so a late-joining
  /// decoder gets parameter sets + an IDR up front. No-op before the gate opens.
  ///
  /// Counts toward the forwarding stats; removes the client on write failure
  /// (it disconnected before we could prime it).
  void _replayKeyframe(Socket socket) {
    final keyframe = _keyframe;
    if (keyframe == null) return;
    try {
      socket.add(keyframe);
      framesForwarded++;
      bytesForwarded += keyframe.length;
    } on Exception catch (_) {
      _removeClient(socket);
    }
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

  /// Stops the server and disconnects all clients.
  void stop() {
    for (final client in List<Socket>.from(_clients)) {
      client.destroy();
    }
    _clients.clear();
    _pending.clear();
    _started = false;
    _keyframe = null;
    _server?.close();
    _server = null;
  }

  /// Releases all resources. Same as [stop] for this server.
  void dispose() => stop();
}
