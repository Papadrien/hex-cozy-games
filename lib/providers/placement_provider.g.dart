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

  @$internal
  @override
  $NotifierProviderElement<Placement, PlacementState> $createElement(
    $ProviderPointer pointer,
  ) => $NotifierProviderElement(pointer);
}

String _$placementHash() => r'0000000000000000000000000000000000000000';

abstract class _$Placement extends $Notifier<PlacementState> {
  PlacementState build();

  @$internal
  @override
  PlacementState runBuild() => build();
}
