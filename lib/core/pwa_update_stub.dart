/// Non-web: no service worker.
Future<bool> detectWaitingServiceWorker() async => false;

Future<void> skipWaitingAndReload() async {}
