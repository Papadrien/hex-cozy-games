// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'placement_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Placement)
const placementProvider = PlacementProvider._();

final class PlacementProvider
    extends $NotifierProvider<Placement, PlacementState> {
  const PlacementProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placementProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placementHash();

  @$internal
  @override
  Placement create() => Placement();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlacementState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlacementState>(value),
    );
  }
}

String _$placementHash() => r'2509dbe62a13c4eb2ada83764d05312e66b80ca2';

abstract class _$Placement extends $Notifier<PlacementState> {
  PlacementState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PlacementState, PlacementState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlacementState, PlacementState>,
              PlacementState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
