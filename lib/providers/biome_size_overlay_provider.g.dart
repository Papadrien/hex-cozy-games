// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biome_size_overlay_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BiomeSizeOverlay)
final biomeSizeOverlayProvider = BiomeSizeOverlayProvider._();

final class BiomeSizeOverlayProvider
    extends $NotifierProvider<BiomeSizeOverlay, bool> {
  BiomeSizeOverlayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biomeSizeOverlayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biomeSizeOverlayHash();

  @$internal
  @override
  BiomeSizeOverlay create() => BiomeSizeOverlay();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$biomeSizeOverlayHash() => r'3a7c9e21f4b6d805c1e9a2f7b4d6081e5c3a9f27';

abstract class _$BiomeSizeOverlay extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
