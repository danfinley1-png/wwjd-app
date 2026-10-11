import 'dart:html' as html;

/// Once-per-call check for a waiting PWA worker after [ServiceWorkerRegistration.update].
///
/// Returns true when a new worker is waiting. Does not reload.
Future<bool> detectWaitingServiceWorker() async {
  final container = html.window.navigator.serviceWorker;
  if (container == null) return false;

  html.ServiceWorkerRegistration registration;
  try {
    registration = await container.getRegistration();
  } catch (_) {
    return false;
  }

  try {
    await registration.update();
  } catch (_) {}

  if (registration.waiting != null) return true;

  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (DateTime.now().isBefore(deadline)) {
    if (registration.waiting != null) return true;
    if (registration.installing == null) break;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return registration.waiting != null;
}

/// Activates the waiting worker and reloads once. Call only from a user tap.
Future<void> skipWaitingAndReload() async {
  try {
    html.window.sessionStorage['wwjd_pwa_reload'] = '1';
  } catch (_) {}

  try {
    final container = html.window.navigator.serviceWorker;
    final registration = await container?.getRegistration();
    final waiting = registration?.waiting;
    waiting?.postMessage('SKIP_WAITING');
    waiting?.postMessage('skipWaiting');
  } catch (_) {}

  html.window.location.reload();
}
