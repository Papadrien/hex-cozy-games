/// Service de demande d'avis — bottom sheet "rate-us".
///
/// Propose une seule fois la bottom sheet de demande d'avis (voir
/// `ui/review_bottom_sheet.dart`), une fois que le joueur a terminé au
/// moins [kReviewPromptGamesThreshold] parties. Le déclenchement effectif
/// (bouton "Noter maintenant" de la bottom sheet, ou lien des Réglages)
/// passe par la boîte de dialogue native (Android In-App Review /
/// `SKStoreReviewController` iOS) quand elle est disponible, avec repli sur
/// l'ouverture directe de la fiche Store sinon.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

const String _kReviewPromptShownKey = 'reviewPromptShown';

/// Identifiant App Store iOS (numérique, visible dans App Store Connect —
/// section "Informations sur l'app"), requis par [InAppReview.openStoreListing]
/// pour rediriger vers la bonne fiche sur iOS. `null` tant que l'app n'est
/// pas encore publiée sur l'App Store : sur Android, `openStoreListing`
/// fonctionne sans cette valeur (utilise l'`applicationId` du manifeste).
// TODO(adben): Renseigner l'App Store ID numérique avant publication iOS.
const String? kIOSAppStoreId = null;

class ReviewService {
  const ReviewService();

  /// Indique si la bottom sheet doit être proposée pour [totalGamesPlayed]
  /// parties jouées au total : seuil atteint et jamais encore proposée
  /// (couvre aussi le cas d'un joueur ayant déjà dépassé le seuil au
  /// moment où cette fonctionnalité est arrivée dans l'app).
  Future<bool> shouldPromptForReview(int totalGamesPlayed) async {
    if (totalGamesPlayed < kReviewPromptGamesThreshold) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kReviewPromptShownKey) ?? false);
  }

  /// Marque la demande comme déjà proposée. Appelé dès l'affichage de la
  /// bottom sheet, quel que soit le choix ("Noter maintenant" ou "Plus
  /// tard") : on ne réinsiste jamais automatiquement — le lien reste
  /// disponible dans les Réglages pour un avis différé.
  Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReviewPromptShownKey, true);
  }

  /// Déclenche la boîte de dialogue d'avis native si disponible (l'OS peut
  /// la refuser silencieusement si son quota d'affichage est atteint),
  /// sinon ouvre directement la fiche Store. Utilisé par le bouton "Noter
  /// maintenant" de la bottom sheet et par le lien des Réglages.
  Future<void> requestReview() async {
    final inAppReview = InAppReview.instance;
    try {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        return;
      }
    } catch (_) {
      // Repli silencieux sur l'ouverture directe de la fiche Store.
    }
    await openStoreListing();
  }

  /// Ouvre directement la fiche de l'app sur le Store, sans passer par la
  /// boîte de dialogue native — comportement attendu depuis un lien
  /// explicite "Laisser un avis" dans les Réglages.
  Future<void> openStoreListing() async {
    try {
      await InAppReview.instance.openStoreListing(appStoreId: kIOSAppStoreId);
    } catch (_) {
      // Store injoignable (émulateur sans Play Store, etc.) — on échoue
      // silencieusement plutôt que de faire planter l'app.
    }
  }
}

final reviewServiceProvider = Provider<ReviewService>(
  (ref) => const ReviewService(),
);
