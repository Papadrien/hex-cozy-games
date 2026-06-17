// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setup_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider de test — valide que Riverpod est correctement configuré
/// (critère d'acceptance story 1.1 : "Riverpod est configuré et un
/// provider de test fonctionne").
///
/// Sera supprimé une fois les vrais providers de l'app en place.

@ProviderFor(setupStatus)
const setupStatusProvider = SetupStatusProvider._();

/// Provider de test — valide que Riverpod est correctement configuré
/// (critère d'acceptance story 1.1 : "Riverpod est configuré et un
/// provider de test fonctionne").
///
/// Sera supprimé une fois les vrais providers de l'app en place.

final class SetupStatusProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Provider de test — valide que Riverpod est correctement configuré
  /// (critère d'acceptance story 1.1 : "Riverpod est configuré et un
  /// provider de test fonctionne").
  ///
  /// Sera supprimé une fois les vrais providers de l'app en place.
  const SetupStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setupStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setupStatusHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return setupStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$setupStatusHash() => r'31be8a6294b7c439b901200b97379ecb5fcd7b6f';
