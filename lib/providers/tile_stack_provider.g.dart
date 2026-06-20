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

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TileStackState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TileStackState>(value),
    );
  }
}

String _$tileStackHash() => r'99077b041e4bdaee84f4c4e9e2f39a3903b91529';

abstract class _$TileStack extends $Notifier<TileStackState> {
  TileStackState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<TileStackState, TileStackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TileStackState, TileStackState>,
              TileStackState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
