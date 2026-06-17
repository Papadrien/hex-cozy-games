import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setup_providers.g.dart';

/// Provider de test — valide que Riverpod est correctement configuré
/// (critère d'acceptance story 1.1 : "Riverpod est configuré et un
/// provider de test fonctionne").
///
/// Sera supprimé une fois les vrais providers de l'app en place.
@riverpod
String setupStatus(Ref ref) => 'Riverpod OK';
