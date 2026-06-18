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
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gridHash();

  @$internal
  @override
  Grid create() => Grid();

  @$internal
  @override
  $NotifierProviderElement<Grid, GridState> $createElement(
    $ProviderPointer pointer,
  ) => $NotifierProviderElement(pointer);
}

String _$gridHash() => r'0000000000000000000000000000000000000000';

abstract class _$Grid extends $Notifier<GridState> {
  GridState build();

  @$internal
  @override
  GridState runBuild() => build();
}
