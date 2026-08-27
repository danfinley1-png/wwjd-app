import 'dart:convert';

import 'package:share_plus/share_plus.dart';

Future<void> exportGiftCalendarFile({
  required String filename,
  required String icsContent,
  String subject = 'WWJD-DI Kingdom Challenge',
}) async {
  final bytes = utf8.encode(icsContent);
  final file = XFile.fromData(
    bytes,
    name: filename,
    mimeType: 'text/calendar',
  );
  await Share.shareXFiles([file], subject: subject);
}
