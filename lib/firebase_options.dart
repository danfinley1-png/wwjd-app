import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyAd3JlqyrrST7wTCjluvtxlL0D5ZQQiyPE",
    appId: "1:28066521495:web:4ae60d76883cba7e7b64d2",
    messagingSenderId: "28066521495",
    projectId: "wwjd-di-e36ce",
    authDomain: "wwjd-di-e36ce.firebaseapp.com",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyAd3JlqyrrST7wTCjluvtxlL0D5ZQQiyPE",
    appId: "1:28066521495:android:2897b9f668922af97b64d2",
    messagingSenderId: "28066521495",
    projectId: "wwjd-di-e36ce",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyAd3JlqyrrST7wTCjluvtxlL0D5ZQQiyPE",
    appId: "1:28066521495:ios:9cfb6eb513c0fd1b7b64d2",
    messagingSenderId: "28066521495",
    projectId: "wwjd-di-e36ce",
    iosBundleId: "com.example.wwjd",
  );
}