import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/saint_playback_errors.dart';

void main() {
  test('demuxer alone does not mention CapCut/HEVC', () {
    const desc =
        'PipelineStatus::DEMUXER_ERROR_COULD_NOT_OPEN: FFmpegDemuxer: open context failed';
    final msg = SaintPlaybackErrors.messageFor(null, errorDescription: desc);
    expect(msg.toLowerCase(), isNot(contains('capcut')));
    expect(msg.toLowerCase(), isNot(contains('hevc')));
  });

  test('src_not_supported without hevc gives generic browser message', () {
    final msg = SaintPlaybackErrors.messageFor(
      Exception('MEDIA_ERR_SRC_NOT_SUPPORTED'),
      errorDescription: 'not supported by your browser',
    );
    expect(msg, contains('H.264'));
    expect(msg.toLowerCase(), isNot(contains('capcut')));
  });

  test('hevc in blob triggers hevc guidance', () {
    final msg = SaintPlaybackErrors.messageFor(
      null,
      errorDescription: 'codec hevc not supported',
    );
    expect(msg, contains('HEVC'));
  });
}
