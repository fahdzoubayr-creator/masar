export 'voice_bytes_stub.dart'
    if (dart.library.html) 'voice_bytes_web.dart'
    if (dart.library.io) 'voice_bytes_io.dart';
