// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grid_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Grid)
const gridProvider = GridProvider._();

final class GridProvider extends $NotifierProvider<Grid, GridState> {
  const GridProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gridProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gridHash();

  @$internal
  @override
  Grid create() => Grid();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GridState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GridState>(value),
    );
  }
}

String _$gridHash() => r'8b89b5ed45c3ef66a24d363557708c92fa6cac29';

abstract class _$Grid extends $Notifier<GridState> {
  GridState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<GridState, GridState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GridState, GridState>,
              GridState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
