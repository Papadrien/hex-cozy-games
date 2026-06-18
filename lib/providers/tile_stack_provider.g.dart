// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tile_stack_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TileStack)
const tileStackProvider = TileStackProvider._();

final class TileStackProvider
    extends $NotifierProvider<TileStack, TileStackState> {
  const TileStackProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tileStackProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tileStackHash();

  @$internal
  @override
  TileStack create() => TileStack();

  @$internal
  @override
  $NotifierProviderElement<TileStack, TileStackState> $createElement(
    $ProviderPointer pointer,
  ) => $NotifierProviderElement(pointer);
}

String _$tileStackHash() => r'0000000000000000000000000000000000000000';

abstract class _$TileStack extends $Notifier<TileStackState> {
  TileStackState build();

  @$internal
  @override
  TileStackState runBuild() => build();
}
