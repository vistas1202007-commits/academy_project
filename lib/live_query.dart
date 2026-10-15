import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shared Firestore listeners.
///
/// Screens build their queries inside build(), and a fresh `.snapshots()`
/// stream on every rebuild made StreamBuilder drop its data and subscribe
/// again (spinner flashes, extra reads, lag while typing in search boxes).
/// With [LiveQuery.liveSnapshots] equal queries get the same stream object,
/// the last result is replayed to every new listener, and the listener stays
/// open for a short while after a screen closes so going back is instant.
const Duration _keepAlive = Duration(seconds: 30);

final Map<Object, _SharedStream<Object?>> _cache = {};

Stream<T> _shared<T>(Object query, Stream<T> Function() open) {
  // Per user, so a new login never sees the previous user's listener
  final key = (FirebaseAuth.instance.currentUser?.uid, query);
  final existing = _cache[key];
  if (existing != null) return existing.stream as Stream<T>;
  final shared = _SharedStream<T>(key, open);
  _cache[key] = shared;
  return shared.stream;
}

class _SharedStream<T> {
  final Object _key;
  final Stream<T> Function() _open;
  final Set<MultiStreamController<T>> _listeners = {};
  StreamSubscription<T>? _sub;
  Timer? _idle;
  T? _latest;
  bool _hasLatest = false;

  _SharedStream(this._key, this._open);

  late final Stream<T> stream = Stream<T>.multi((controller) {
    _idle?.cancel();
    _idle = null;
    if (_hasLatest) controller.add(_latest as T);
    _listeners.add(controller);
    _sub ??= _open().listen(
      (value) {
        _latest = value;
        _hasLatest = true;
        for (final l in [..._listeners]) {
          l.add(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        for (final l in [..._listeners]) {
          l.addError(error, stack);
        }
        // Next build gets a fresh listener, so a retry is possible
        _close();
      },
    );
    controller.onCancel = () {
      _listeners.remove(controller);
      if (_listeners.isEmpty) _idle = Timer(_keepAlive, _close);
    };
  });

  void _close() {
    _idle?.cancel();
    _idle = null;
    _sub?.cancel();
    _sub = null;
    _latest = null;
    _hasLatest = false;
    if (identical(_cache[_key], this)) _cache.remove(_key);
  }
}

extension LiveQuery<T> on Query<T> {
  /// Use instead of `snapshots()`; safe to call inside build()
  Stream<QuerySnapshot<T>> liveSnapshots() => _shared(this, snapshots);
}

extension LiveDocument<T> on DocumentReference<T> {
  /// Use instead of `snapshots()`; safe to call inside build()
  Stream<DocumentSnapshot<T>> liveSnapshots() => _shared(this, snapshots);
}
