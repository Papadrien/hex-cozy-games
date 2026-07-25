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

String _$holdSlotHash() => r'6ad196ed3ed7d2dcef3d35abafd7f134a787196e';

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
