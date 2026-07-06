// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hold_slot_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HoldSlot)
final holdSlotProvider = HoldSlotProvider._();

final class HoldSlotProvider
    extends $NotifierProvider<HoldSlot, HoldSlotState> {
  HoldSlotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'holdSlotProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$holdSlotHash();

  @$internal
  @override
  HoldSlot create() => HoldSlot();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HoldSlotState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HoldSlotState>(value),
    );
  }
}

String _$holdSlotHash() => r'6f2c3e1a9d7b4058f6d2e1c9a3b7f0248d5c9e1a';

abstract class _$HoldSlot extends $Notifier<HoldSlotState> {
  HoldSlotState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<HoldSlotState, HoldSlotState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HoldSlotState, HoldSlotState>,
              HoldSlotState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
