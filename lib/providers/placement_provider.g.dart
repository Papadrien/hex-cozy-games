// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'placement_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Placement)
final placementProvider = PlacementProvider._();

final class PlacementProvider
    extends $NotifierProvider<Placement, PlacementState> {
  PlacementProvider._()
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

String _$placementHash() => r'e60e4a9c43c3934a92bd2a5479f3c63a08d4932d';

abstract class _$Placement extends $Notifier<PlacementState> {
  PlacementState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlacementState, PlacementState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlacementState, PlacementState>,
              PlacementState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
