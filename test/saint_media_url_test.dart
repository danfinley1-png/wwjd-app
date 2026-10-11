import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/saint_media_url.dart';

void main() {
  test('storagePathFromDownloadUrl decodes Saints path', () {
    const url =
        'https://firebasestorage.googleapis.com/v0/b/wwjd-di-e36ce.firebasestorage.app/o/Saints%2F2026-09-23-pio-pietrelcina%2Fportrait.mp4?alt=media&token=abc';
    expect(
      SaintMediaUrl.storagePathFromDownloadUrl(url),
      'Saints/2026-09-23-pio-pietrelcina/portrait.mp4',
    );
  });

  test('storagePathFromDownloadUrl decodes Peter Claver feast folder', () {
    const portrait =
        'https://firebasestorage.googleapis.com/v0/b/wwjd-di-e36ce.firebasestorage.app/o/Saints%2F2026-09-09-peter-claver%2Fportrait.mp4?alt=media&token=x';
    const landscape =
        'https://firebasestorage.googleapis.com/v0/b/wwjd-di-e36ce.firebasestorage.app/o/Saints%2F2026-09-09-peter-claver%2Flandscape.mp4?alt=media&token=x';
    expect(
      SaintMediaUrl.storagePathFromDownloadUrl(portrait),
      'Saints/2026-09-09-peter-claver/portrait.mp4',
    );
    expect(
      SaintMediaUrl.storagePathFromDownloadUrl(landscape),
      'Saints/2026-09-09-peter-claver/landscape.mp4',
    );
  });
}
