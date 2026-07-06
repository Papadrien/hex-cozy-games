// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'second_chance_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SecondChanceMode)
final secondChanceModeProvider = SecondChanceModeProvider._();

final class SecondChanceModeProvider
    extends $NotifierProvider<SecondChanceMode, bool> {
  SecondChanceModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secondChanceModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secondChanceModeHash();

  @$internal
  @override
  SecondChanceMode create() => SecondChanceMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$secondChanceModeHash() => r'a1f3c8e5b2d947106f8b3e2a5c9d1e4f7b8a0c3d';

abstract class _$SecondChanceMode extends $Notifier<bool> {
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
