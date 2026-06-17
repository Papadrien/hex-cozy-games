import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Encapsule l'initialisation de Firebase Analytics et Crashlytics.
///
/// Le projet Firebase n'est pas encore créé pour ce jeu : tant que
/// `android/app/google-services.json` (et l'équivalent iOS) n'est pas
/// fourni, `Firebase.initializeApp()` échoue. On capture cet échec pour
/// que l'app démarre normalement en mode dégradé (Analytics/Crashlytics
/// désactivés) plutôt que de planter au lancement — même logique que
/// Raccoon Bandit pour l'injection CI du secret `GOOGLE_SERVICES_JSON_BASE64`.
class AnalyticsService {
  AnalyticsService._();

  static bool _isAvailable = false;

  /// True si Firebase a pu être initialisé (google-services.json présent).
  static bool get isAvailable => _isAvailable;

  /// Initialise Firebase. À appeler une fois dans `main()` avant `runApp`.
  ///
  /// Ne lève jamais d'exception : en cas d'échec (config absente), l'app
  /// continue de fonctionner sans Analytics/Crashlytics.
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();

      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      _isAvailable = true;
      debugPrint('✅ Firebase initialisé (Analytics + Crashlytics actifs)');

      // Critère d'acceptance story 1.1 : "test event envoyé".
      await logEvent('app_setup_complete');
    } catch (e) {
      _isAvailable = false;
      debugPrint(
        '⚠️ Firebase non initialisé (google-services.json absent ?) — '
        'Analytics et Crashlytics désactivés. Erreur : $e',
      );
    }
  }

  /// Envoie un événement Analytics si Firebase est disponible, no-op sinon.
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!_isAvailable) return;
    await FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: parameters,
    );
  }
}
