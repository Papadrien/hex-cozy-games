// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SetupCheckTable extends SetupCheck
    with TableInfo<$SetupCheckTable, SetupCheckRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetupCheckTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setup_check';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetupCheckRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetupCheckRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetupCheckRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
    );
  }

  @override
  $SetupCheckTable createAlias(String alias) {
    return $SetupCheckTable(attachedDatabase, alias);
  }
}

class SetupCheckRow extends DataClass implements Insertable<SetupCheckRow> {
  final int id;
  final String label;
  const SetupCheckRow({required this.id, required this.label});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    return map;
  }

  SetupCheckCompanion toCompanion(bool nullToAbsent) {
    return SetupCheckCompanion(id: Value(id), label: Value(label));
  }

  factory SetupCheckRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetupCheckRow(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
    };
  }

  SetupCheckRow copyWith({int? id, String? label}) =>
      SetupCheckRow(id: id ?? this.id, label: label ?? this.label);
  SetupCheckRow copyWithCompanion(SetupCheckCompanion data) {
    return SetupCheckRow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetupCheckRow(')
          ..write('id: $id, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetupCheckRow &&
          other.id == this.id &&
          other.label == this.label);
}

class SetupCheckCompanion extends UpdateCompanion<SetupCheckRow> {
  final Value<int> id;
  final Value<String> label;
  const SetupCheckCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
  });
  SetupCheckCompanion.insert({
    this.id = const Value.absent(),
    required String label,
  }) : label = Value(label);
  static Insertable<SetupCheckRow> custom({
    Expression<int>? id,
    Expression<String>? label,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
    });
  }

  SetupCheckCompanion copyWith({Value<int>? id, Value<String>? label}) {
    return SetupCheckCompanion(id: id ?? this.id, label: label ?? this.label);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetupCheckCompanion(')
          ..write('id: $id, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }
}

class $GameSessionTable extends GameSession
    with TableInfo<$GameSessionTable, GameSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameSessionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _gridStateMeta = const VerificationMeta(
    'gridState',
  );
  @override
  late final GeneratedColumn<String> gridState = GeneratedColumn<String>(
    'grid_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tileStackMeta = const VerificationMeta(
    'tileStack',
  );
  @override
  late final GeneratedColumn<String> tileStack = GeneratedColumn<String>(
    'tile_stack',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coinsMeta = const VerificationMeta('coins');
  @override
  late final GeneratedColumn<int> coins = GeneratedColumn<int>(
    'coins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalBonusTilesMeta = const VerificationMeta(
    'totalBonusTiles',
  );
  @override
  late final GeneratedColumn<int> totalBonusTiles = GeneratedColumn<int>(
    'total_bonus_tiles',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastTilePlacedMeta = const VerificationMeta(
    'lastTilePlaced',
  );
  @override
  late final GeneratedColumn<String> lastTilePlaced = GeneratedColumn<String>(
    'last_tile_placed',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _placedTilesCountMeta = const VerificationMeta(
    'placedTilesCount',
  );
  @override
  late final GeneratedColumn<int> placedTilesCount = GeneratedColumn<int>(
    'placed_tiles_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    gridState,
    tileStack,
    coins,
    totalBonusTiles,
    lastTilePlaced,
    placedTilesCount,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_session';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('grid_state')) {
      context.handle(
        _gridStateMeta,
        gridState.isAcceptableOrUnknown(data['grid_state']!, _gridStateMeta),
      );
    } else if (isInserting) {
      context.missing(_gridStateMeta);
    }
    if (data.containsKey('tile_stack')) {
      context.handle(
        _tileStackMeta,
        tileStack.isAcceptableOrUnknown(data['tile_stack']!, _tileStackMeta),
      );
    } else if (isInserting) {
      context.missing(_tileStackMeta);
    }
    if (data.containsKey('coins')) {
      context.handle(
        _coinsMeta,
        coins.isAcceptableOrUnknown(data['coins']!, _coinsMeta),
      );
    } else if (isInserting) {
      context.missing(_coinsMeta);
    }
    if (data.containsKey('total_bonus_tiles')) {
      context.handle(
        _totalBonusTilesMeta,
        totalBonusTiles.isAcceptableOrUnknown(
          data['total_bonus_tiles']!,
          _totalBonusTilesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalBonusTilesMeta);
    }
    if (data.containsKey('last_tile_placed')) {
      context.handle(
        _lastTilePlacedMeta,
        lastTilePlaced.isAcceptableOrUnknown(
          data['last_tile_placed']!,
          _lastTilePlacedMeta,
        ),
      );
    }
    if (data.containsKey('placed_tiles_count')) {
      context.handle(
        _placedTilesCountMeta,
        placedTilesCount.isAcceptableOrUnknown(
          data['placed_tiles_count']!,
          _placedTilesCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_placedTilesCountMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      gridState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grid_state'],
      )!,
      tileStack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tile_stack'],
      )!,
      coins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins'],
      )!,
      totalBonusTiles: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bonus_tiles'],
      )!,
      lastTilePlaced: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_tile_placed'],
      ),
      placedTilesCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}placed_tiles_count'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GameSessionTable createAlias(String alias) {
    return $GameSessionTable(attachedDatabase, alias);
  }
}

class GameSessionRow extends DataClass implements Insertable<GameSessionRow> {
  final int id;
  final String gridState;
  final String tileStack;
  final int coins;
  final int totalBonusTiles;
  final String? lastTilePlaced;
  final int placedTilesCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const GameSessionRow({
    required this.id,
    required this.gridState,
    required this.tileStack,
    required this.coins,
    required this.totalBonusTiles,
    this.lastTilePlaced,
    required this.placedTilesCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['grid_state'] = Variable<String>(gridState);
    map['tile_stack'] = Variable<String>(tileStack);
    map['coins'] = Variable<int>(coins);
    map['total_bonus_tiles'] = Variable<int>(totalBonusTiles);
    if (!nullToAbsent || lastTilePlaced != null) {
      map['last_tile_placed'] = Variable<String>(lastTilePlaced);
    }
    map['placed_tiles_count'] = Variable<int>(placedTilesCount);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GameSessionCompanion toCompanion(bool nullToAbsent) {
    return GameSessionCompanion(
      id: Value(id),
      gridState: Value(gridState),
      tileStack: Value(tileStack),
      coins: Value(coins),
      totalBonusTiles: Value(totalBonusTiles),
      lastTilePlaced: lastTilePlaced == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTilePlaced),
      placedTilesCount: Value(placedTilesCount),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GameSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameSessionRow(
      id: serializer.fromJson<int>(json['id']),
      gridState: serializer.fromJson<String>(json['gridState']),
      tileStack: serializer.fromJson<String>(json['tileStack']),
      coins: serializer.fromJson<int>(json['coins']),
      totalBonusTiles: serializer.fromJson<int>(json['totalBonusTiles']),
      lastTilePlaced: serializer.fromJson<String?>(json['lastTilePlaced']),
      placedTilesCount: serializer.fromJson<int>(json['placedTilesCount']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'gridState': serializer.toJson<String>(gridState),
      'tileStack': serializer.toJson<String>(tileStack),
      'coins': serializer.toJson<int>(coins),
      'totalBonusTiles': serializer.toJson<int>(totalBonusTiles),
      'lastTilePlaced': serializer.toJson<String?>(lastTilePlaced),
      'placedTilesCount': serializer.toJson<int>(placedTilesCount),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GameSessionRow copyWith({
    int? id,
    String? gridState,
    String? tileStack,
    int? coins,
    int? totalBonusTiles,
    Value<String?> lastTilePlaced = const Value.absent(),
    int? placedTilesCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GameSessionRow(
    id: id ?? this.id,
    gridState: gridState ?? this.gridState,
    tileStack: tileStack ?? this.tileStack,
    coins: coins ?? this.coins,
    totalBonusTiles: totalBonusTiles ?? this.totalBonusTiles,
    lastTilePlaced: lastTilePlaced.present
        ? lastTilePlaced.value
        : this.lastTilePlaced,
    placedTilesCount: placedTilesCount ?? this.placedTilesCount,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GameSessionRow copyWithCompanion(GameSessionCompanion data) {
    return GameSessionRow(
      id: data.id.present ? data.id.value : this.id,
      gridState: data.gridState.present ? data.gridState.value : this.gridState,
      tileStack: data.tileStack.present ? data.tileStack.value : this.tileStack,
      coins: data.coins.present ? data.coins.value : this.coins,
      totalBonusTiles: data.totalBonusTiles.present
          ? data.totalBonusTiles.value
          : this.totalBonusTiles,
      lastTilePlaced: data.lastTilePlaced.present
          ? data.lastTilePlaced.value
          : this.lastTilePlaced,
      placedTilesCount: data.placedTilesCount.present
          ? data.placedTilesCount.value
          : this.placedTilesCount,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameSessionRow(')
          ..write('id: $id, ')
          ..write('gridState: $gridState, ')
          ..write('tileStack: $tileStack, ')
          ..write('coins: $coins, ')
          ..write('totalBonusTiles: $totalBonusTiles, ')
          ..write('lastTilePlaced: $lastTilePlaced, ')
          ..write('placedTilesCount: $placedTilesCount, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    gridState,
    tileStack,
    coins,
    totalBonusTiles,
    lastTilePlaced,
    placedTilesCount,
    isActive,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameSessionRow &&
          other.id == this.id &&
          other.gridState == this.gridState &&
          other.tileStack == this.tileStack &&
          other.coins == this.coins &&
          other.totalBonusTiles == this.totalBonusTiles &&
          other.lastTilePlaced == this.lastTilePlaced &&
          other.placedTilesCount == this.placedTilesCount &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GameSessionCompanion extends UpdateCompanion<GameSessionRow> {
  final Value<int> id;
  final Value<String> gridState;
  final Value<String> tileStack;
  final Value<int> coins;
  final Value<int> totalBonusTiles;
  final Value<String?> lastTilePlaced;
  final Value<int> placedTilesCount;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const GameSessionCompanion({
    this.id = const Value.absent(),
    this.gridState = const Value.absent(),
    this.tileStack = const Value.absent(),
    this.coins = const Value.absent(),
    this.totalBonusTiles = const Value.absent(),
    this.lastTilePlaced = const Value.absent(),
    this.placedTilesCount = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GameSessionCompanion.insert({
    this.id = const Value.absent(),
    required String gridState,
    required String tileStack,
    required int coins,
    required int totalBonusTiles,
    this.lastTilePlaced = const Value.absent(),
    required int placedTilesCount,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : gridState = Value(gridState),
       tileStack = Value(tileStack),
       coins = Value(coins),
       totalBonusTiles = Value(totalBonusTiles),
       placedTilesCount = Value(placedTilesCount),
       isActive = Value(isActive),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GameSessionRow> custom({
    Expression<int>? id,
    Expression<String>? gridState,
    Expression<String>? tileStack,
    Expression<int>? coins,
    Expression<int>? totalBonusTiles,
    Expression<String>? lastTilePlaced,
    Expression<int>? placedTilesCount,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gridState != null) 'grid_state': gridState,
      if (tileStack != null) 'tile_stack': tileStack,
      if (coins != null) 'coins': coins,
      if (totalBonusTiles != null) 'total_bonus_tiles': totalBonusTiles,
      if (lastTilePlaced != null) 'last_tile_placed': lastTilePlaced,
      if (placedTilesCount != null) 'placed_tiles_count': placedTilesCount,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GameSessionCompanion copyWith({
    Value<int>? id,
    Value<String>? gridState,
    Value<String>? tileStack,
    Value<int>? coins,
    Value<int>? totalBonusTiles,
    Value<String?>? lastTilePlaced,
    Value<int>? placedTilesCount,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return GameSessionCompanion(
      id: id ?? this.id,
      gridState: gridState ?? this.gridState,
      tileStack: tileStack ?? this.tileStack,
      coins: coins ?? this.coins,
      totalBonusTiles: totalBonusTiles ?? this.totalBonusTiles,
      lastTilePlaced: lastTilePlaced ?? this.lastTilePlaced,
      placedTilesCount: placedTilesCount ?? this.placedTilesCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (gridState.present) {
      map['grid_state'] = Variable<String>(gridState.value);
    }
    if (tileStack.present) {
      map['tile_stack'] = Variable<String>(tileStack.value);
    }
    if (coins.present) {
      map['coins'] = Variable<int>(coins.value);
    }
    if (totalBonusTiles.present) {
      map['total_bonus_tiles'] = Variable<int>(totalBonusTiles.value);
    }
    if (lastTilePlaced.present) {
      map['last_tile_placed'] = Variable<String>(lastTilePlaced.value);
    }
    if (placedTilesCount.present) {
      map['placed_tiles_count'] = Variable<int>(placedTilesCount.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameSessionCompanion(')
          ..write('id: $id, ')
          ..write('gridState: $gridState, ')
          ..write('tileStack: $tileStack, ')
          ..write('coins: $coins, ')
          ..write('totalBonusTiles: $totalBonusTiles, ')
          ..write('lastTilePlaced: $lastTilePlaced, ')
          ..write('placedTilesCount: $placedTilesCount, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlayerProfileTable extends PlayerProfile
    with TableInfo<$PlayerProfileTable, PlayerProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayerProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _coinsMeta = const VerificationMeta('coins');
  @override
  late final GeneratedColumn<int> coins = GeneratedColumn<int>(
    'coins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalTilesPlacedMeta = const VerificationMeta(
    'totalTilesPlaced',
  );
  @override
  late final GeneratedColumn<int> totalTilesPlaced = GeneratedColumn<int>(
    'total_tiles_placed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPremiumMeta = const VerificationMeta(
    'isPremium',
  );
  @override
  late final GeneratedColumn<bool> isPremium = GeneratedColumn<bool>(
    'is_premium',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_premium" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastDailyRewardDateMeta =
      const VerificationMeta('lastDailyRewardDate');
  @override
  late final GeneratedColumn<DateTime> lastDailyRewardDate =
      GeneratedColumn<DateTime>(
        'last_daily_reward_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    coins,
    totalTilesPlaced,
    isPremium,
    lastDailyRewardDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'player_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayerProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('coins')) {
      context.handle(
        _coinsMeta,
        coins.isAcceptableOrUnknown(data['coins']!, _coinsMeta),
      );
    }
    if (data.containsKey('total_tiles_placed')) {
      context.handle(
        _totalTilesPlacedMeta,
        totalTilesPlaced.isAcceptableOrUnknown(
          data['total_tiles_placed']!,
          _totalTilesPlacedMeta,
        ),
      );
    }
    if (data.containsKey('is_premium')) {
      context.handle(
        _isPremiumMeta,
        isPremium.isAcceptableOrUnknown(data['is_premium']!, _isPremiumMeta),
      );
    }
    if (data.containsKey('last_daily_reward_date')) {
      context.handle(
        _lastDailyRewardDateMeta,
        lastDailyRewardDate.isAcceptableOrUnknown(
          data['last_daily_reward_date']!,
          _lastDailyRewardDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayerProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayerProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      coins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins'],
      )!,
      totalTilesPlaced: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_tiles_placed'],
      )!,
      isPremium: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_premium'],
      )!,
      lastDailyRewardDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_daily_reward_date'],
      ),
    );
  }

  @override
  $PlayerProfileTable createAlias(String alias) {
    return $PlayerProfileTable(attachedDatabase, alias);
  }
}

class PlayerProfileRow extends DataClass
    implements Insertable<PlayerProfileRow> {
  final int id;
  final int coins;
  final int totalTilesPlaced;
  final bool isPremium;
  final DateTime? lastDailyRewardDate;
  const PlayerProfileRow({
    required this.id,
    required this.coins,
    required this.totalTilesPlaced,
    required this.isPremium,
    this.lastDailyRewardDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['coins'] = Variable<int>(coins);
    map['total_tiles_placed'] = Variable<int>(totalTilesPlaced);
    map['is_premium'] = Variable<bool>(isPremium);
    if (!nullToAbsent || lastDailyRewardDate != null) {
      map['last_daily_reward_date'] = Variable<DateTime>(lastDailyRewardDate);
    }
    return map;
  }

  PlayerProfileCompanion toCompanion(bool nullToAbsent) {
    return PlayerProfileCompanion(
      id: Value(id),
      coins: Value(coins),
      totalTilesPlaced: Value(totalTilesPlaced),
      isPremium: Value(isPremium),
      lastDailyRewardDate: lastDailyRewardDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDailyRewardDate),
    );
  }

  factory PlayerProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayerProfileRow(
      id: serializer.fromJson<int>(json['id']),
      coins: serializer.fromJson<int>(json['coins']),
      totalTilesPlaced: serializer.fromJson<int>(json['totalTilesPlaced']),
      isPremium: serializer.fromJson<bool>(json['isPremium']),
      lastDailyRewardDate: serializer.fromJson<DateTime?>(
        json['lastDailyRewardDate'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'coins': serializer.toJson<int>(coins),
      'totalTilesPlaced': serializer.toJson<int>(totalTilesPlaced),
      'isPremium': serializer.toJson<bool>(isPremium),
      'lastDailyRewardDate': serializer.toJson<DateTime?>(lastDailyRewardDate),
    };
  }

  PlayerProfileRow copyWith({
    int? id,
    int? coins,
    int? totalTilesPlaced,
    bool? isPremium,
    Value<DateTime?> lastDailyRewardDate = const Value.absent(),
  }) => PlayerProfileRow(
    id: id ?? this.id,
    coins: coins ?? this.coins,
    totalTilesPlaced: totalTilesPlaced ?? this.totalTilesPlaced,
    isPremium: isPremium ?? this.isPremium,
    lastDailyRewardDate: lastDailyRewardDate.present
        ? lastDailyRewardDate.value
        : this.lastDailyRewardDate,
  );
  PlayerProfileRow copyWithCompanion(PlayerProfileCompanion data) {
    return PlayerProfileRow(
      id: data.id.present ? data.id.value : this.id,
      coins: data.coins.present ? data.coins.value : this.coins,
      totalTilesPlaced: data.totalTilesPlaced.present
          ? data.totalTilesPlaced.value
          : this.totalTilesPlaced,
      isPremium: data.isPremium.present ? data.isPremium.value : this.isPremium,
      lastDailyRewardDate: data.lastDailyRewardDate.present
          ? data.lastDailyRewardDate.value
          : this.lastDailyRewardDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerProfileRow(')
          ..write('id: $id, ')
          ..write('coins: $coins, ')
          ..write('totalTilesPlaced: $totalTilesPlaced, ')
          ..write('isPremium: $isPremium, ')
          ..write('lastDailyRewardDate: $lastDailyRewardDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, coins, totalTilesPlaced, isPremium, lastDailyRewardDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerProfileRow &&
          other.id == this.id &&
          other.coins == this.coins &&
          other.totalTilesPlaced == this.totalTilesPlaced &&
          other.isPremium == this.isPremium &&
          other.lastDailyRewardDate == this.lastDailyRewardDate);
}

class PlayerProfileCompanion extends UpdateCompanion<PlayerProfileRow> {
  final Value<int> id;
  final Value<int> coins;
  final Value<int> totalTilesPlaced;
  final Value<bool> isPremium;
  final Value<DateTime?> lastDailyRewardDate;
  const PlayerProfileCompanion({
    this.id = const Value.absent(),
    this.coins = const Value.absent(),
    this.totalTilesPlaced = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.lastDailyRewardDate = const Value.absent(),
  });
  PlayerProfileCompanion.insert({
    this.id = const Value.absent(),
    this.coins = const Value.absent(),
    this.totalTilesPlaced = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.lastDailyRewardDate = const Value.absent(),
  });
  static Insertable<PlayerProfileRow> custom({
    Expression<int>? id,
    Expression<int>? coins,
    Expression<int>? totalTilesPlaced,
    Expression<bool>? isPremium,
    Expression<DateTime>? lastDailyRewardDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (coins != null) 'coins': coins,
      if (totalTilesPlaced != null) 'total_tiles_placed': totalTilesPlaced,
      if (isPremium != null) 'is_premium': isPremium,
      if (lastDailyRewardDate != null)
        'last_daily_reward_date': lastDailyRewardDate,
    });
  }

  PlayerProfileCompanion copyWith({
    Value<int>? id,
    Value<int>? coins,
    Value<int>? totalTilesPlaced,
    Value<bool>? isPremium,
    Value<DateTime?>? lastDailyRewardDate,
  }) {
    return PlayerProfileCompanion(
      id: id ?? this.id,
      coins: coins ?? this.coins,
      totalTilesPlaced: totalTilesPlaced ?? this.totalTilesPlaced,
      isPremium: isPremium ?? this.isPremium,
      lastDailyRewardDate: lastDailyRewardDate ?? this.lastDailyRewardDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (coins.present) {
      map['coins'] = Variable<int>(coins.value);
    }
    if (totalTilesPlaced.present) {
      map['total_tiles_placed'] = Variable<int>(totalTilesPlaced.value);
    }
    if (isPremium.present) {
      map['is_premium'] = Variable<bool>(isPremium.value);
    }
    if (lastDailyRewardDate.present) {
      map['last_daily_reward_date'] = Variable<DateTime>(
        lastDailyRewardDate.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayerProfileCompanion(')
          ..write('id: $id, ')
          ..write('coins: $coins, ')
          ..write('totalTilesPlaced: $totalTilesPlaced, ')
          ..write('isPremium: $isPremium, ')
          ..write('lastDailyRewardDate: $lastDailyRewardDate')
          ..write(')'))
        .toString();
  }
}

class $UpgradesTable extends Upgrades
    with TableInfo<$UpgradesTable, UpgradeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UpgradesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectTypeMeta = const VerificationMeta(
    'effectType',
  );
  @override
  late final GeneratedColumn<String> effectType = GeneratedColumn<String>(
    'effect_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isUnlockedMeta = const VerificationMeta(
    'isUnlocked',
  );
  @override
  late final GeneratedColumn<bool> isUnlocked = GeneratedColumn<bool>(
    'is_unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_unlocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _currentLevelMeta = const VerificationMeta(
    'currentLevel',
  );
  @override
  late final GeneratedColumn<int> currentLevel = GeneratedColumn<int>(
    'current_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unlockConditionTypeMeta =
      const VerificationMeta('unlockConditionType');
  @override
  late final GeneratedColumn<String> unlockConditionType =
      GeneratedColumn<String>(
        'unlock_condition_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _unlockConditionValueMeta =
      const VerificationMeta('unlockConditionValue');
  @override
  late final GeneratedColumn<int> unlockConditionValue = GeneratedColumn<int>(
    'unlock_condition_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    effectType,
    isUnlocked,
    currentLevel,
    unlockConditionType,
    unlockConditionValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'upgrades';
  @override
  VerificationContext validateIntegrity(
    Insertable<UpgradeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('effect_type')) {
      context.handle(
        _effectTypeMeta,
        effectType.isAcceptableOrUnknown(data['effect_type']!, _effectTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_effectTypeMeta);
    }
    if (data.containsKey('is_unlocked')) {
      context.handle(
        _isUnlockedMeta,
        isUnlocked.isAcceptableOrUnknown(data['is_unlocked']!, _isUnlockedMeta),
      );
    }
    if (data.containsKey('current_level')) {
      context.handle(
        _currentLevelMeta,
        currentLevel.isAcceptableOrUnknown(
          data['current_level']!,
          _currentLevelMeta,
        ),
      );
    }
    if (data.containsKey('unlock_condition_type')) {
      context.handle(
        _unlockConditionTypeMeta,
        unlockConditionType.isAcceptableOrUnknown(
          data['unlock_condition_type']!,
          _unlockConditionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unlockConditionTypeMeta);
    }
    if (data.containsKey('unlock_condition_value')) {
      context.handle(
        _unlockConditionValueMeta,
        unlockConditionValue.isAcceptableOrUnknown(
          data['unlock_condition_value']!,
          _unlockConditionValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unlockConditionValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UpgradeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UpgradeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      effectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effect_type'],
      )!,
      isUnlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_unlocked'],
      )!,
      currentLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_level'],
      )!,
      unlockConditionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unlock_condition_type'],
      )!,
      unlockConditionValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unlock_condition_value'],
      )!,
    );
  }

  @override
  $UpgradesTable createAlias(String alias) {
    return $UpgradesTable(attachedDatabase, alias);
  }
}

class UpgradeRow extends DataClass implements Insertable<UpgradeRow> {
  final String id;
  final String name;
  final String effectType;
  final bool isUnlocked;
  final int currentLevel;
  final String unlockConditionType;
  final int unlockConditionValue;
  const UpgradeRow({
    required this.id,
    required this.name,
    required this.effectType,
    required this.isUnlocked,
    required this.currentLevel,
    required this.unlockConditionType,
    required this.unlockConditionValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['effect_type'] = Variable<String>(effectType);
    map['is_unlocked'] = Variable<bool>(isUnlocked);
    map['current_level'] = Variable<int>(currentLevel);
    map['unlock_condition_type'] = Variable<String>(unlockConditionType);
    map['unlock_condition_value'] = Variable<int>(unlockConditionValue);
    return map;
  }

  UpgradesCompanion toCompanion(bool nullToAbsent) {
    return UpgradesCompanion(
      id: Value(id),
      name: Value(name),
      effectType: Value(effectType),
      isUnlocked: Value(isUnlocked),
      currentLevel: Value(currentLevel),
      unlockConditionType: Value(unlockConditionType),
      unlockConditionValue: Value(unlockConditionValue),
    );
  }

  factory UpgradeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UpgradeRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      effectType: serializer.fromJson<String>(json['effectType']),
      isUnlocked: serializer.fromJson<bool>(json['isUnlocked']),
      currentLevel: serializer.fromJson<int>(json['currentLevel']),
      unlockConditionType: serializer.fromJson<String>(
        json['unlockConditionType'],
      ),
      unlockConditionValue: serializer.fromJson<int>(
        json['unlockConditionValue'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'effectType': serializer.toJson<String>(effectType),
      'isUnlocked': serializer.toJson<bool>(isUnlocked),
      'currentLevel': serializer.toJson<int>(currentLevel),
      'unlockConditionType': serializer.toJson<String>(unlockConditionType),
      'unlockConditionValue': serializer.toJson<int>(unlockConditionValue),
    };
  }

  UpgradeRow copyWith({
    String? id,
    String? name,
    String? effectType,
    bool? isUnlocked,
    int? currentLevel,
    String? unlockConditionType,
    int? unlockConditionValue,
  }) => UpgradeRow(
    id: id ?? this.id,
    name: name ?? this.name,
    effectType: effectType ?? this.effectType,
    isUnlocked: isUnlocked ?? this.isUnlocked,
    currentLevel: currentLevel ?? this.currentLevel,
    unlockConditionType: unlockConditionType ?? this.unlockConditionType,
    unlockConditionValue: unlockConditionValue ?? this.unlockConditionValue,
  );
  UpgradeRow copyWithCompanion(UpgradesCompanion data) {
    return UpgradeRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      effectType: data.effectType.present
          ? data.effectType.value
          : this.effectType,
      isUnlocked: data.isUnlocked.present
          ? data.isUnlocked.value
          : this.isUnlocked,
      currentLevel: data.currentLevel.present
          ? data.currentLevel.value
          : this.currentLevel,
      unlockConditionType: data.unlockConditionType.present
          ? data.unlockConditionType.value
          : this.unlockConditionType,
      unlockConditionValue: data.unlockConditionValue.present
          ? data.unlockConditionValue.value
          : this.unlockConditionValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UpgradeRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('effectType: $effectType, ')
          ..write('isUnlocked: $isUnlocked, ')
          ..write('currentLevel: $currentLevel, ')
          ..write('unlockConditionType: $unlockConditionType, ')
          ..write('unlockConditionValue: $unlockConditionValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    effectType,
    isUnlocked,
    currentLevel,
    unlockConditionType,
    unlockConditionValue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpgradeRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.effectType == this.effectType &&
          other.isUnlocked == this.isUnlocked &&
          other.currentLevel == this.currentLevel &&
          other.unlockConditionType == this.unlockConditionType &&
          other.unlockConditionValue == this.unlockConditionValue);
}

class UpgradesCompanion extends UpdateCompanion<UpgradeRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> effectType;
  final Value<bool> isUnlocked;
  final Value<int> currentLevel;
  final Value<String> unlockConditionType;
  final Value<int> unlockConditionValue;
  final Value<int> rowid;
  const UpgradesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.effectType = const Value.absent(),
    this.isUnlocked = const Value.absent(),
    this.currentLevel = const Value.absent(),
    this.unlockConditionType = const Value.absent(),
    this.unlockConditionValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UpgradesCompanion.insert({
    required String id,
    required String name,
    required String effectType,
    this.isUnlocked = const Value.absent(),
    this.currentLevel = const Value.absent(),
    required String unlockConditionType,
    required int unlockConditionValue,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       effectType = Value(effectType),
       unlockConditionType = Value(unlockConditionType),
       unlockConditionValue = Value(unlockConditionValue);
  static Insertable<UpgradeRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? effectType,
    Expression<bool>? isUnlocked,
    Expression<int>? currentLevel,
    Expression<String>? unlockConditionType,
    Expression<int>? unlockConditionValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (effectType != null) 'effect_type': effectType,
      if (isUnlocked != null) 'is_unlocked': isUnlocked,
      if (currentLevel != null) 'current_level': currentLevel,
      if (unlockConditionType != null)
        'unlock_condition_type': unlockConditionType,
      if (unlockConditionValue != null)
        'unlock_condition_value': unlockConditionValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UpgradesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? effectType,
    Value<bool>? isUnlocked,
    Value<int>? currentLevel,
    Value<String>? unlockConditionType,
    Value<int>? unlockConditionValue,
    Value<int>? rowid,
  }) {
    return UpgradesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      effectType: effectType ?? this.effectType,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      currentLevel: currentLevel ?? this.currentLevel,
      unlockConditionType: unlockConditionType ?? this.unlockConditionType,
      unlockConditionValue: unlockConditionValue ?? this.unlockConditionValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (effectType.present) {
      map['effect_type'] = Variable<String>(effectType.value);
    }
    if (isUnlocked.present) {
      map['is_unlocked'] = Variable<bool>(isUnlocked.value);
    }
    if (currentLevel.present) {
      map['current_level'] = Variable<int>(currentLevel.value);
    }
    if (unlockConditionType.present) {
      map['unlock_condition_type'] = Variable<String>(
        unlockConditionType.value,
      );
    }
    if (unlockConditionValue.present) {
      map['unlock_condition_value'] = Variable<int>(unlockConditionValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UpgradesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('effectType: $effectType, ')
          ..write('isUnlocked: $isUnlocked, ')
          ..write('currentLevel: $currentLevel, ')
          ..write('unlockConditionType: $unlockConditionType, ')
          ..write('unlockConditionValue: $unlockConditionValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PermanentQuestsTable extends PermanentQuests
    with TableInfo<$PermanentQuestsTable, PermanentQuestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PermanentQuestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetValueMeta = const VerificationMeta(
    'targetValue',
  );
  @override
  late final GeneratedColumn<int> targetValue = GeneratedColumn<int>(
    'target_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentValueMeta = const VerificationMeta(
    'currentValue',
  );
  @override
  late final GeneratedColumn<int> currentValue = GeneratedColumn<int>(
    'current_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rewardTypeMeta = const VerificationMeta(
    'rewardType',
  );
  @override
  late final GeneratedColumn<String> rewardType = GeneratedColumn<String>(
    'reward_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rewardValueMeta = const VerificationMeta(
    'rewardValue',
  );
  @override
  late final GeneratedColumn<int> rewardValue = GeneratedColumn<int>(
    'reward_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextQuestIdMeta = const VerificationMeta(
    'nextQuestId',
  );
  @override
  late final GeneratedColumn<String> nextQuestId = GeneratedColumn<String>(
    'next_quest_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    description,
    targetValue,
    currentValue,
    isCompleted,
    rewardType,
    rewardValue,
    nextQuestId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'permanent_quests';
  @override
  VerificationContext validateIntegrity(
    Insertable<PermanentQuestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('target_value')) {
      context.handle(
        _targetValueMeta,
        targetValue.isAcceptableOrUnknown(
          data['target_value']!,
          _targetValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetValueMeta);
    }
    if (data.containsKey('current_value')) {
      context.handle(
        _currentValueMeta,
        currentValue.isAcceptableOrUnknown(
          data['current_value']!,
          _currentValueMeta,
        ),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('reward_type')) {
      context.handle(
        _rewardTypeMeta,
        rewardType.isAcceptableOrUnknown(data['reward_type']!, _rewardTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_rewardTypeMeta);
    }
    if (data.containsKey('reward_value')) {
      context.handle(
        _rewardValueMeta,
        rewardValue.isAcceptableOrUnknown(
          data['reward_value']!,
          _rewardValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rewardValueMeta);
    }
    if (data.containsKey('next_quest_id')) {
      context.handle(
        _nextQuestIdMeta,
        nextQuestId.isAcceptableOrUnknown(
          data['next_quest_id']!,
          _nextQuestIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PermanentQuestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PermanentQuestRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      targetValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_value'],
      )!,
      currentValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_value'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      rewardType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reward_type'],
      )!,
      rewardValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reward_value'],
      )!,
      nextQuestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_quest_id'],
      ),
    );
  }

  @override
  $PermanentQuestsTable createAlias(String alias) {
    return $PermanentQuestsTable(attachedDatabase, alias);
  }
}

class PermanentQuestRow extends DataClass
    implements Insertable<PermanentQuestRow> {
  final String id;
  final String category;
  final String description;
  final int targetValue;
  final int currentValue;
  final bool isCompleted;
  final String rewardType;
  final int rewardValue;
  final String? nextQuestId;
  const PermanentQuestRow({
    required this.id,
    required this.category,
    required this.description,
    required this.targetValue,
    required this.currentValue,
    required this.isCompleted,
    required this.rewardType,
    required this.rewardValue,
    this.nextQuestId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    map['description'] = Variable<String>(description);
    map['target_value'] = Variable<int>(targetValue);
    map['current_value'] = Variable<int>(currentValue);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['reward_type'] = Variable<String>(rewardType);
    map['reward_value'] = Variable<int>(rewardValue);
    if (!nullToAbsent || nextQuestId != null) {
      map['next_quest_id'] = Variable<String>(nextQuestId);
    }
    return map;
  }

  PermanentQuestsCompanion toCompanion(bool nullToAbsent) {
    return PermanentQuestsCompanion(
      id: Value(id),
      category: Value(category),
      description: Value(description),
      targetValue: Value(targetValue),
      currentValue: Value(currentValue),
      isCompleted: Value(isCompleted),
      rewardType: Value(rewardType),
      rewardValue: Value(rewardValue),
      nextQuestId: nextQuestId == null && nullToAbsent
          ? const Value.absent()
          : Value(nextQuestId),
    );
  }

  factory PermanentQuestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PermanentQuestRow(
      id: serializer.fromJson<String>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      description: serializer.fromJson<String>(json['description']),
      targetValue: serializer.fromJson<int>(json['targetValue']),
      currentValue: serializer.fromJson<int>(json['currentValue']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      rewardType: serializer.fromJson<String>(json['rewardType']),
      rewardValue: serializer.fromJson<int>(json['rewardValue']),
      nextQuestId: serializer.fromJson<String?>(json['nextQuestId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category': serializer.toJson<String>(category),
      'description': serializer.toJson<String>(description),
      'targetValue': serializer.toJson<int>(targetValue),
      'currentValue': serializer.toJson<int>(currentValue),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'rewardType': serializer.toJson<String>(rewardType),
      'rewardValue': serializer.toJson<int>(rewardValue),
      'nextQuestId': serializer.toJson<String?>(nextQuestId),
    };
  }

  PermanentQuestRow copyWith({
    String? id,
    String? category,
    String? description,
    int? targetValue,
    int? currentValue,
    bool? isCompleted,
    String? rewardType,
    int? rewardValue,
    Value<String?> nextQuestId = const Value.absent(),
  }) => PermanentQuestRow(
    id: id ?? this.id,
    category: category ?? this.category,
    description: description ?? this.description,
    targetValue: targetValue ?? this.targetValue,
    currentValue: currentValue ?? this.currentValue,
    isCompleted: isCompleted ?? this.isCompleted,
    rewardType: rewardType ?? this.rewardType,
    rewardValue: rewardValue ?? this.rewardValue,
    nextQuestId: nextQuestId.present ? nextQuestId.value : this.nextQuestId,
  );
  PermanentQuestRow copyWithCompanion(PermanentQuestsCompanion data) {
    return PermanentQuestRow(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      targetValue: data.targetValue.present
          ? data.targetValue.value
          : this.targetValue,
      currentValue: data.currentValue.present
          ? data.currentValue.value
          : this.currentValue,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      rewardType: data.rewardType.present
          ? data.rewardType.value
          : this.rewardType,
      rewardValue: data.rewardValue.present
          ? data.rewardValue.value
          : this.rewardValue,
      nextQuestId: data.nextQuestId.present
          ? data.nextQuestId.value
          : this.nextQuestId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PermanentQuestRow(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('targetValue: $targetValue, ')
          ..write('currentValue: $currentValue, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('rewardType: $rewardType, ')
          ..write('rewardValue: $rewardValue, ')
          ..write('nextQuestId: $nextQuestId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    description,
    targetValue,
    currentValue,
    isCompleted,
    rewardType,
    rewardValue,
    nextQuestId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermanentQuestRow &&
          other.id == this.id &&
          other.category == this.category &&
          other.description == this.description &&
          other.targetValue == this.targetValue &&
          other.currentValue == this.currentValue &&
          other.isCompleted == this.isCompleted &&
          other.rewardType == this.rewardType &&
          other.rewardValue == this.rewardValue &&
          other.nextQuestId == this.nextQuestId);
}

class PermanentQuestsCompanion extends UpdateCompanion<PermanentQuestRow> {
  final Value<String> id;
  final Value<String> category;
  final Value<String> description;
  final Value<int> targetValue;
  final Value<int> currentValue;
  final Value<bool> isCompleted;
  final Value<String> rewardType;
  final Value<int> rewardValue;
  final Value<String?> nextQuestId;
  final Value<int> rowid;
  const PermanentQuestsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.targetValue = const Value.absent(),
    this.currentValue = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.rewardType = const Value.absent(),
    this.rewardValue = const Value.absent(),
    this.nextQuestId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PermanentQuestsCompanion.insert({
    required String id,
    required String category,
    required String description,
    required int targetValue,
    this.currentValue = const Value.absent(),
    this.isCompleted = const Value.absent(),
    required String rewardType,
    required int rewardValue,
    this.nextQuestId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       description = Value(description),
       targetValue = Value(targetValue),
       rewardType = Value(rewardType),
       rewardValue = Value(rewardValue);
  static Insertable<PermanentQuestRow> custom({
    Expression<String>? id,
    Expression<String>? category,
    Expression<String>? description,
    Expression<int>? targetValue,
    Expression<int>? currentValue,
    Expression<bool>? isCompleted,
    Expression<String>? rewardType,
    Expression<int>? rewardValue,
    Expression<String>? nextQuestId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (targetValue != null) 'target_value': targetValue,
      if (currentValue != null) 'current_value': currentValue,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (rewardType != null) 'reward_type': rewardType,
      if (rewardValue != null) 'reward_value': rewardValue,
      if (nextQuestId != null) 'next_quest_id': nextQuestId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PermanentQuestsCompanion copyWith({
    Value<String>? id,
    Value<String>? category,
    Value<String>? description,
    Value<int>? targetValue,
    Value<int>? currentValue,
    Value<bool>? isCompleted,
    Value<String>? rewardType,
    Value<int>? rewardValue,
    Value<String?>? nextQuestId,
    Value<int>? rowid,
  }) {
    return PermanentQuestsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      isCompleted: isCompleted ?? this.isCompleted,
      rewardType: rewardType ?? this.rewardType,
      rewardValue: rewardValue ?? this.rewardValue,
      nextQuestId: nextQuestId ?? this.nextQuestId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (targetValue.present) {
      map['target_value'] = Variable<int>(targetValue.value);
    }
    if (currentValue.present) {
      map['current_value'] = Variable<int>(currentValue.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (rewardType.present) {
      map['reward_type'] = Variable<String>(rewardType.value);
    }
    if (rewardValue.present) {
      map['reward_value'] = Variable<int>(rewardValue.value);
    }
    if (nextQuestId.present) {
      map['next_quest_id'] = Variable<String>(nextQuestId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PermanentQuestsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('targetValue: $targetValue, ')
          ..write('currentValue: $currentValue, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('rewardType: $rewardType, ')
          ..write('rewardValue: $rewardValue, ')
          ..write('nextQuestId: $nextQuestId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyQuestsTable extends DailyQuests
    with TableInfo<$DailyQuestsTable, DailyQuestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyQuestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questPoolIdsMeta = const VerificationMeta(
    'questPoolIds',
  );
  @override
  late final GeneratedColumn<String> questPoolIds = GeneratedColumn<String>(
    'quest_pool_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedIdsMeta = const VerificationMeta(
    'completedIds',
  );
  @override
  late final GeneratedColumn<String> completedIds = GeneratedColumn<String>(
    'completed_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressByQuestIdMeta = const VerificationMeta(
    'progressByQuestId',
  );
  @override
  late final GeneratedColumn<String> progressByQuestId =
      GeneratedColumn<String>(
        'progress_by_quest_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    questPoolIds,
    completedIds,
    progressByQuestId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_quests';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyQuestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('quest_pool_ids')) {
      context.handle(
        _questPoolIdsMeta,
        questPoolIds.isAcceptableOrUnknown(
          data['quest_pool_ids']!,
          _questPoolIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questPoolIdsMeta);
    }
    if (data.containsKey('completed_ids')) {
      context.handle(
        _completedIdsMeta,
        completedIds.isAcceptableOrUnknown(
          data['completed_ids']!,
          _completedIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedIdsMeta);
    }
    if (data.containsKey('progress_by_quest_id')) {
      context.handle(
        _progressByQuestIdMeta,
        progressByQuestId.isAcceptableOrUnknown(
          data['progress_by_quest_id']!,
          _progressByQuestIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_progressByQuestIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyQuestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyQuestRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      questPoolIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quest_pool_ids'],
      )!,
      completedIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_ids'],
      )!,
      progressByQuestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}progress_by_quest_id'],
      )!,
    );
  }

  @override
  $DailyQuestsTable createAlias(String alias) {
    return $DailyQuestsTable(attachedDatabase, alias);
  }
}

class DailyQuestRow extends DataClass implements Insertable<DailyQuestRow> {
  final int id;
  final DateTime date;
  final String questPoolIds;
  final String completedIds;
  final String progressByQuestId;
  const DailyQuestRow({
    required this.id,
    required this.date,
    required this.questPoolIds,
    required this.completedIds,
    required this.progressByQuestId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['quest_pool_ids'] = Variable<String>(questPoolIds);
    map['completed_ids'] = Variable<String>(completedIds);
    map['progress_by_quest_id'] = Variable<String>(progressByQuestId);
    return map;
  }

  DailyQuestsCompanion toCompanion(bool nullToAbsent) {
    return DailyQuestsCompanion(
      id: Value(id),
      date: Value(date),
      questPoolIds: Value(questPoolIds),
      completedIds: Value(completedIds),
      progressByQuestId: Value(progressByQuestId),
    );
  }

  factory DailyQuestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyQuestRow(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      questPoolIds: serializer.fromJson<String>(json['questPoolIds']),
      completedIds: serializer.fromJson<String>(json['completedIds']),
      progressByQuestId: serializer.fromJson<String>(json['progressByQuestId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'questPoolIds': serializer.toJson<String>(questPoolIds),
      'completedIds': serializer.toJson<String>(completedIds),
      'progressByQuestId': serializer.toJson<String>(progressByQuestId),
    };
  }

  DailyQuestRow copyWith({
    int? id,
    DateTime? date,
    String? questPoolIds,
    String? completedIds,
    String? progressByQuestId,
  }) => DailyQuestRow(
    id: id ?? this.id,
    date: date ?? this.date,
    questPoolIds: questPoolIds ?? this.questPoolIds,
    completedIds: completedIds ?? this.completedIds,
    progressByQuestId: progressByQuestId ?? this.progressByQuestId,
  );
  DailyQuestRow copyWithCompanion(DailyQuestsCompanion data) {
    return DailyQuestRow(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      questPoolIds: data.questPoolIds.present
          ? data.questPoolIds.value
          : this.questPoolIds,
      completedIds: data.completedIds.present
          ? data.completedIds.value
          : this.completedIds,
      progressByQuestId: data.progressByQuestId.present
          ? data.progressByQuestId.value
          : this.progressByQuestId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyQuestRow(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('questPoolIds: $questPoolIds, ')
          ..write('completedIds: $completedIds, ')
          ..write('progressByQuestId: $progressByQuestId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, questPoolIds, completedIds, progressByQuestId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyQuestRow &&
          other.id == this.id &&
          other.date == this.date &&
          other.questPoolIds == this.questPoolIds &&
          other.completedIds == this.completedIds &&
          other.progressByQuestId == this.progressByQuestId);
}

class DailyQuestsCompanion extends UpdateCompanion<DailyQuestRow> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> questPoolIds;
  final Value<String> completedIds;
  final Value<String> progressByQuestId;
  const DailyQuestsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.questPoolIds = const Value.absent(),
    this.completedIds = const Value.absent(),
    this.progressByQuestId = const Value.absent(),
  });
  DailyQuestsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String questPoolIds,
    required String completedIds,
    required String progressByQuestId,
  }) : date = Value(date),
       questPoolIds = Value(questPoolIds),
       completedIds = Value(completedIds),
       progressByQuestId = Value(progressByQuestId);
  static Insertable<DailyQuestRow> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? questPoolIds,
    Expression<String>? completedIds,
    Expression<String>? progressByQuestId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (questPoolIds != null) 'quest_pool_ids': questPoolIds,
      if (completedIds != null) 'completed_ids': completedIds,
      if (progressByQuestId != null) 'progress_by_quest_id': progressByQuestId,
    });
  }

  DailyQuestsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? questPoolIds,
    Value<String>? completedIds,
    Value<String>? progressByQuestId,
  }) {
    return DailyQuestsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      questPoolIds: questPoolIds ?? this.questPoolIds,
      completedIds: completedIds ?? this.completedIds,
      progressByQuestId: progressByQuestId ?? this.progressByQuestId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (questPoolIds.present) {
      map['quest_pool_ids'] = Variable<String>(questPoolIds.value);
    }
    if (completedIds.present) {
      map['completed_ids'] = Variable<String>(completedIds.value);
    }
    if (progressByQuestId.present) {
      map['progress_by_quest_id'] = Variable<String>(progressByQuestId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyQuestsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('questPoolIds: $questPoolIds, ')
          ..write('completedIds: $completedIds, ')
          ..write('progressByQuestId: $progressByQuestId')
          ..write(')'))
        .toString();
  }
}

class $GameSessionsTable extends GameSessions
    with TableInfo<$GameSessionsTable, MetaGameSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _tilesRemainingMeta = const VerificationMeta(
    'tilesRemaining',
  );
  @override
  late final GeneratedColumn<int> tilesRemaining = GeneratedColumn<int>(
    'tiles_remaining',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedUpgradeIdsMeta =
      const VerificationMeta('selectedUpgradeIds');
  @override
  late final GeneratedColumn<String> selectedUpgradeIds =
      GeneratedColumn<String>(
        'selected_upgrade_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _coinsEarnedMeta = const VerificationMeta(
    'coinsEarned',
  );
  @override
  late final GeneratedColumn<int> coinsEarned = GeneratedColumn<int>(
    'coins_earned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tilesPlacedMeta = const VerificationMeta(
    'tilesPlaced',
  );
  @override
  late final GeneratedColumn<int> tilesPlaced = GeneratedColumn<int>(
    'tiles_placed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gridStateMeta = const VerificationMeta(
    'gridState',
  );
  @override
  late final GeneratedColumn<String> gridState = GeneratedColumn<String>(
    'grid_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tileStackMeta = const VerificationMeta(
    'tileStack',
  );
  @override
  late final GeneratedColumn<String> tileStack = GeneratedColumn<String>(
    'tile_stack',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastTilePlacedMeta = const VerificationMeta(
    'lastTilePlaced',
  );
  @override
  late final GeneratedColumn<String> lastTilePlaced = GeneratedColumn<String>(
    'last_tile_placed',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seedMeta = const VerificationMeta('seed');
  @override
  late final GeneratedColumn<int> seed = GeneratedColumn<int>(
    'seed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    isActive,
    tilesRemaining,
    selectedUpgradeIds,
    coinsEarned,
    tilesPlaced,
    gridState,
    tileStack,
    lastTilePlaced,
    seed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaGameSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('tiles_remaining')) {
      context.handle(
        _tilesRemainingMeta,
        tilesRemaining.isAcceptableOrUnknown(
          data['tiles_remaining']!,
          _tilesRemainingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tilesRemainingMeta);
    }
    if (data.containsKey('selected_upgrade_ids')) {
      context.handle(
        _selectedUpgradeIdsMeta,
        selectedUpgradeIds.isAcceptableOrUnknown(
          data['selected_upgrade_ids']!,
          _selectedUpgradeIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedUpgradeIdsMeta);
    }
    if (data.containsKey('coins_earned')) {
      context.handle(
        _coinsEarnedMeta,
        coinsEarned.isAcceptableOrUnknown(
          data['coins_earned']!,
          _coinsEarnedMeta,
        ),
      );
    }
    if (data.containsKey('tiles_placed')) {
      context.handle(
        _tilesPlacedMeta,
        tilesPlaced.isAcceptableOrUnknown(
          data['tiles_placed']!,
          _tilesPlacedMeta,
        ),
      );
    }
    if (data.containsKey('grid_state')) {
      context.handle(
        _gridStateMeta,
        gridState.isAcceptableOrUnknown(data['grid_state']!, _gridStateMeta),
      );
    } else if (isInserting) {
      context.missing(_gridStateMeta);
    }
    if (data.containsKey('tile_stack')) {
      context.handle(
        _tileStackMeta,
        tileStack.isAcceptableOrUnknown(data['tile_stack']!, _tileStackMeta),
      );
    } else if (isInserting) {
      context.missing(_tileStackMeta);
    }
    if (data.containsKey('last_tile_placed')) {
      context.handle(
        _lastTilePlacedMeta,
        lastTilePlaced.isAcceptableOrUnknown(
          data['last_tile_placed']!,
          _lastTilePlacedMeta,
        ),
      );
    }
    if (data.containsKey('seed')) {
      context.handle(
        _seedMeta,
        seed.isAcceptableOrUnknown(data['seed']!, _seedMeta),
      );
    } else if (isInserting) {
      context.missing(_seedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MetaGameSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaGameSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      tilesRemaining: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tiles_remaining'],
      )!,
      selectedUpgradeIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_upgrade_ids'],
      )!,
      coinsEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins_earned'],
      )!,
      tilesPlaced: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tiles_placed'],
      )!,
      gridState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grid_state'],
      )!,
      tileStack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tile_stack'],
      )!,
      lastTilePlaced: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_tile_placed'],
      ),
      seed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed'],
      )!,
    );
  }

  @override
  $GameSessionsTable createAlias(String alias) {
    return $GameSessionsTable(attachedDatabase, alias);
  }
}

class MetaGameSessionRow extends DataClass
    implements Insertable<MetaGameSessionRow> {
  final int id;
  final bool isActive;
  final int tilesRemaining;
  final String selectedUpgradeIds;
  final int coinsEarned;
  final int tilesPlaced;
  final String gridState;
  final String tileStack;
  final String? lastTilePlaced;
  final int seed;
  const MetaGameSessionRow({
    required this.id,
    required this.isActive,
    required this.tilesRemaining,
    required this.selectedUpgradeIds,
    required this.coinsEarned,
    required this.tilesPlaced,
    required this.gridState,
    required this.tileStack,
    this.lastTilePlaced,
    required this.seed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['is_active'] = Variable<bool>(isActive);
    map['tiles_remaining'] = Variable<int>(tilesRemaining);
    map['selected_upgrade_ids'] = Variable<String>(selectedUpgradeIds);
    map['coins_earned'] = Variable<int>(coinsEarned);
    map['tiles_placed'] = Variable<int>(tilesPlaced);
    map['grid_state'] = Variable<String>(gridState);
    map['tile_stack'] = Variable<String>(tileStack);
    if (!nullToAbsent || lastTilePlaced != null) {
      map['last_tile_placed'] = Variable<String>(lastTilePlaced);
    }
    map['seed'] = Variable<int>(seed);
    return map;
  }

  GameSessionsCompanion toCompanion(bool nullToAbsent) {
    return GameSessionsCompanion(
      id: Value(id),
      isActive: Value(isActive),
      tilesRemaining: Value(tilesRemaining),
      selectedUpgradeIds: Value(selectedUpgradeIds),
      coinsEarned: Value(coinsEarned),
      tilesPlaced: Value(tilesPlaced),
      gridState: Value(gridState),
      tileStack: Value(tileStack),
      lastTilePlaced: lastTilePlaced == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTilePlaced),
      seed: Value(seed),
    );
  }

  factory MetaGameSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaGameSessionRow(
      id: serializer.fromJson<int>(json['id']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      tilesRemaining: serializer.fromJson<int>(json['tilesRemaining']),
      selectedUpgradeIds: serializer.fromJson<String>(
        json['selectedUpgradeIds'],
      ),
      coinsEarned: serializer.fromJson<int>(json['coinsEarned']),
      tilesPlaced: serializer.fromJson<int>(json['tilesPlaced']),
      gridState: serializer.fromJson<String>(json['gridState']),
      tileStack: serializer.fromJson<String>(json['tileStack']),
      lastTilePlaced: serializer.fromJson<String?>(json['lastTilePlaced']),
      seed: serializer.fromJson<int>(json['seed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'isActive': serializer.toJson<bool>(isActive),
      'tilesRemaining': serializer.toJson<int>(tilesRemaining),
      'selectedUpgradeIds': serializer.toJson<String>(selectedUpgradeIds),
      'coinsEarned': serializer.toJson<int>(coinsEarned),
      'tilesPlaced': serializer.toJson<int>(tilesPlaced),
      'gridState': serializer.toJson<String>(gridState),
      'tileStack': serializer.toJson<String>(tileStack),
      'lastTilePlaced': serializer.toJson<String?>(lastTilePlaced),
      'seed': serializer.toJson<int>(seed),
    };
  }

  MetaGameSessionRow copyWith({
    int? id,
    bool? isActive,
    int? tilesRemaining,
    String? selectedUpgradeIds,
    int? coinsEarned,
    int? tilesPlaced,
    String? gridState,
    String? tileStack,
    Value<String?> lastTilePlaced = const Value.absent(),
    int? seed,
  }) => MetaGameSessionRow(
    id: id ?? this.id,
    isActive: isActive ?? this.isActive,
    tilesRemaining: tilesRemaining ?? this.tilesRemaining,
    selectedUpgradeIds: selectedUpgradeIds ?? this.selectedUpgradeIds,
    coinsEarned: coinsEarned ?? this.coinsEarned,
    tilesPlaced: tilesPlaced ?? this.tilesPlaced,
    gridState: gridState ?? this.gridState,
    tileStack: tileStack ?? this.tileStack,
    lastTilePlaced: lastTilePlaced.present
        ? lastTilePlaced.value
        : this.lastTilePlaced,
    seed: seed ?? this.seed,
  );
  MetaGameSessionRow copyWithCompanion(GameSessionsCompanion data) {
    return MetaGameSessionRow(
      id: data.id.present ? data.id.value : this.id,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      tilesRemaining: data.tilesRemaining.present
          ? data.tilesRemaining.value
          : this.tilesRemaining,
      selectedUpgradeIds: data.selectedUpgradeIds.present
          ? data.selectedUpgradeIds.value
          : this.selectedUpgradeIds,
      coinsEarned: data.coinsEarned.present
          ? data.coinsEarned.value
          : this.coinsEarned,
      tilesPlaced: data.tilesPlaced.present
          ? data.tilesPlaced.value
          : this.tilesPlaced,
      gridState: data.gridState.present ? data.gridState.value : this.gridState,
      tileStack: data.tileStack.present ? data.tileStack.value : this.tileStack,
      lastTilePlaced: data.lastTilePlaced.present
          ? data.lastTilePlaced.value
          : this.lastTilePlaced,
      seed: data.seed.present ? data.seed.value : this.seed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaGameSessionRow(')
          ..write('id: $id, ')
          ..write('isActive: $isActive, ')
          ..write('tilesRemaining: $tilesRemaining, ')
          ..write('selectedUpgradeIds: $selectedUpgradeIds, ')
          ..write('coinsEarned: $coinsEarned, ')
          ..write('tilesPlaced: $tilesPlaced, ')
          ..write('gridState: $gridState, ')
          ..write('tileStack: $tileStack, ')
          ..write('lastTilePlaced: $lastTilePlaced, ')
          ..write('seed: $seed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    isActive,
    tilesRemaining,
    selectedUpgradeIds,
    coinsEarned,
    tilesPlaced,
    gridState,
    tileStack,
    lastTilePlaced,
    seed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaGameSessionRow &&
          other.id == this.id &&
          other.isActive == this.isActive &&
          other.tilesRemaining == this.tilesRemaining &&
          other.selectedUpgradeIds == this.selectedUpgradeIds &&
          other.coinsEarned == this.coinsEarned &&
          other.tilesPlaced == this.tilesPlaced &&
          other.gridState == this.gridState &&
          other.tileStack == this.tileStack &&
          other.lastTilePlaced == this.lastTilePlaced &&
          other.seed == this.seed);
}

class GameSessionsCompanion extends UpdateCompanion<MetaGameSessionRow> {
  final Value<int> id;
  final Value<bool> isActive;
  final Value<int> tilesRemaining;
  final Value<String> selectedUpgradeIds;
  final Value<int> coinsEarned;
  final Value<int> tilesPlaced;
  final Value<String> gridState;
  final Value<String> tileStack;
  final Value<String?> lastTilePlaced;
  final Value<int> seed;
  const GameSessionsCompanion({
    this.id = const Value.absent(),
    this.isActive = const Value.absent(),
    this.tilesRemaining = const Value.absent(),
    this.selectedUpgradeIds = const Value.absent(),
    this.coinsEarned = const Value.absent(),
    this.tilesPlaced = const Value.absent(),
    this.gridState = const Value.absent(),
    this.tileStack = const Value.absent(),
    this.lastTilePlaced = const Value.absent(),
    this.seed = const Value.absent(),
  });
  GameSessionsCompanion.insert({
    this.id = const Value.absent(),
    this.isActive = const Value.absent(),
    required int tilesRemaining,
    required String selectedUpgradeIds,
    this.coinsEarned = const Value.absent(),
    this.tilesPlaced = const Value.absent(),
    required String gridState,
    required String tileStack,
    this.lastTilePlaced = const Value.absent(),
    required int seed,
  }) : tilesRemaining = Value(tilesRemaining),
       selectedUpgradeIds = Value(selectedUpgradeIds),
       gridState = Value(gridState),
       tileStack = Value(tileStack),
       seed = Value(seed);
  static Insertable<MetaGameSessionRow> custom({
    Expression<int>? id,
    Expression<bool>? isActive,
    Expression<int>? tilesRemaining,
    Expression<String>? selectedUpgradeIds,
    Expression<int>? coinsEarned,
    Expression<int>? tilesPlaced,
    Expression<String>? gridState,
    Expression<String>? tileStack,
    Expression<String>? lastTilePlaced,
    Expression<int>? seed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isActive != null) 'is_active': isActive,
      if (tilesRemaining != null) 'tiles_remaining': tilesRemaining,
      if (selectedUpgradeIds != null)
        'selected_upgrade_ids': selectedUpgradeIds,
      if (coinsEarned != null) 'coins_earned': coinsEarned,
      if (tilesPlaced != null) 'tiles_placed': tilesPlaced,
      if (gridState != null) 'grid_state': gridState,
      if (tileStack != null) 'tile_stack': tileStack,
      if (lastTilePlaced != null) 'last_tile_placed': lastTilePlaced,
      if (seed != null) 'seed': seed,
    });
  }

  GameSessionsCompanion copyWith({
    Value<int>? id,
    Value<bool>? isActive,
    Value<int>? tilesRemaining,
    Value<String>? selectedUpgradeIds,
    Value<int>? coinsEarned,
    Value<int>? tilesPlaced,
    Value<String>? gridState,
    Value<String>? tileStack,
    Value<String?>? lastTilePlaced,
    Value<int>? seed,
  }) {
    return GameSessionsCompanion(
      id: id ?? this.id,
      isActive: isActive ?? this.isActive,
      tilesRemaining: tilesRemaining ?? this.tilesRemaining,
      selectedUpgradeIds: selectedUpgradeIds ?? this.selectedUpgradeIds,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      tilesPlaced: tilesPlaced ?? this.tilesPlaced,
      gridState: gridState ?? this.gridState,
      tileStack: tileStack ?? this.tileStack,
      lastTilePlaced: lastTilePlaced ?? this.lastTilePlaced,
      seed: seed ?? this.seed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (tilesRemaining.present) {
      map['tiles_remaining'] = Variable<int>(tilesRemaining.value);
    }
    if (selectedUpgradeIds.present) {
      map['selected_upgrade_ids'] = Variable<String>(selectedUpgradeIds.value);
    }
    if (coinsEarned.present) {
      map['coins_earned'] = Variable<int>(coinsEarned.value);
    }
    if (tilesPlaced.present) {
      map['tiles_placed'] = Variable<int>(tilesPlaced.value);
    }
    if (gridState.present) {
      map['grid_state'] = Variable<String>(gridState.value);
    }
    if (tileStack.present) {
      map['tile_stack'] = Variable<String>(tileStack.value);
    }
    if (lastTilePlaced.present) {
      map['last_tile_placed'] = Variable<String>(lastTilePlaced.value);
    }
    if (seed.present) {
      map['seed'] = Variable<int>(seed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameSessionsCompanion(')
          ..write('id: $id, ')
          ..write('isActive: $isActive, ')
          ..write('tilesRemaining: $tilesRemaining, ')
          ..write('selectedUpgradeIds: $selectedUpgradeIds, ')
          ..write('coinsEarned: $coinsEarned, ')
          ..write('tilesPlaced: $tilesPlaced, ')
          ..write('gridState: $gridState, ')
          ..write('tileStack: $tileStack, ')
          ..write('lastTilePlaced: $lastTilePlaced, ')
          ..write('seed: $seed')
          ..write(')'))
        .toString();
  }
}

class $PlayerStatsTable extends PlayerStats
    with TableInfo<$PlayerStatsTable, PlayerStatsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayerStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _totalTilesPlacedMeta = const VerificationMeta(
    'totalTilesPlaced',
  );
  @override
  late final GeneratedColumn<int> totalTilesPlaced = GeneratedColumn<int>(
    'total_tiles_placed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalGamesPlayedMeta = const VerificationMeta(
    'totalGamesPlayed',
  );
  @override
  late final GeneratedColumn<int> totalGamesPlayed = GeneratedColumn<int>(
    'total_games_played',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalCoinsEarnedMeta = const VerificationMeta(
    'totalCoinsEarned',
  );
  @override
  late final GeneratedColumn<int> totalCoinsEarned = GeneratedColumn<int>(
    'total_coins_earned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bestScoreMeta = const VerificationMeta(
    'bestScore',
  );
  @override
  late final GeneratedColumn<int> bestScore = GeneratedColumn<int>(
    'best_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxBiomeSizesMeta = const VerificationMeta(
    'maxBiomeSizes',
  );
  @override
  late final GeneratedColumn<String> maxBiomeSizes = GeneratedColumn<String>(
    'max_biome_sizes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    totalTilesPlaced,
    totalGamesPlayed,
    totalCoinsEarned,
    bestScore,
    maxBiomeSizes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'player_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayerStatsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('total_tiles_placed')) {
      context.handle(
        _totalTilesPlacedMeta,
        totalTilesPlaced.isAcceptableOrUnknown(
          data['total_tiles_placed']!,
          _totalTilesPlacedMeta,
        ),
      );
    }
    if (data.containsKey('total_games_played')) {
      context.handle(
        _totalGamesPlayedMeta,
        totalGamesPlayed.isAcceptableOrUnknown(
          data['total_games_played']!,
          _totalGamesPlayedMeta,
        ),
      );
    }
    if (data.containsKey('total_coins_earned')) {
      context.handle(
        _totalCoinsEarnedMeta,
        totalCoinsEarned.isAcceptableOrUnknown(
          data['total_coins_earned']!,
          _totalCoinsEarnedMeta,
        ),
      );
    }
    if (data.containsKey('best_score')) {
      context.handle(
        _bestScoreMeta,
        bestScore.isAcceptableOrUnknown(data['best_score']!, _bestScoreMeta),
      );
    }
    if (data.containsKey('max_biome_sizes')) {
      context.handle(
        _maxBiomeSizesMeta,
        maxBiomeSizes.isAcceptableOrUnknown(
          data['max_biome_sizes']!,
          _maxBiomeSizesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxBiomeSizesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayerStatsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayerStatsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      totalTilesPlaced: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_tiles_placed'],
      )!,
      totalGamesPlayed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_games_played'],
      )!,
      totalCoinsEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_coins_earned'],
      )!,
      bestScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}best_score'],
      )!,
      maxBiomeSizes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}max_biome_sizes'],
      )!,
    );
  }

  @override
  $PlayerStatsTable createAlias(String alias) {
    return $PlayerStatsTable(attachedDatabase, alias);
  }
}

class PlayerStatsRow extends DataClass implements Insertable<PlayerStatsRow> {
  final int id;
  final int totalTilesPlaced;
  final int totalGamesPlayed;
  final int totalCoinsEarned;
  final int bestScore;
  final String maxBiomeSizes;
  const PlayerStatsRow({
    required this.id,
    required this.totalTilesPlaced,
    required this.totalGamesPlayed,
    required this.totalCoinsEarned,
    required this.bestScore,
    required this.maxBiomeSizes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['total_tiles_placed'] = Variable<int>(totalTilesPlaced);
    map['total_games_played'] = Variable<int>(totalGamesPlayed);
    map['total_coins_earned'] = Variable<int>(totalCoinsEarned);
    map['best_score'] = Variable<int>(bestScore);
    map['max_biome_sizes'] = Variable<String>(maxBiomeSizes);
    return map;
  }

  PlayerStatsCompanion toCompanion(bool nullToAbsent) {
    return PlayerStatsCompanion(
      id: Value(id),
      totalTilesPlaced: Value(totalTilesPlaced),
      totalGamesPlayed: Value(totalGamesPlayed),
      totalCoinsEarned: Value(totalCoinsEarned),
      bestScore: Value(bestScore),
      maxBiomeSizes: Value(maxBiomeSizes),
    );
  }

  factory PlayerStatsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayerStatsRow(
      id: serializer.fromJson<int>(json['id']),
      totalTilesPlaced: serializer.fromJson<int>(json['totalTilesPlaced']),
      totalGamesPlayed: serializer.fromJson<int>(json['totalGamesPlayed']),
      totalCoinsEarned: serializer.fromJson<int>(json['totalCoinsEarned']),
      bestScore: serializer.fromJson<int>(json['bestScore']),
      maxBiomeSizes: serializer.fromJson<String>(json['maxBiomeSizes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'totalTilesPlaced': serializer.toJson<int>(totalTilesPlaced),
      'totalGamesPlayed': serializer.toJson<int>(totalGamesPlayed),
      'totalCoinsEarned': serializer.toJson<int>(totalCoinsEarned),
      'bestScore': serializer.toJson<int>(bestScore),
      'maxBiomeSizes': serializer.toJson<String>(maxBiomeSizes),
    };
  }

  PlayerStatsRow copyWith({
    int? id,
    int? totalTilesPlaced,
    int? totalGamesPlayed,
    int? totalCoinsEarned,
    int? bestScore,
    String? maxBiomeSizes,
  }) => PlayerStatsRow(
    id: id ?? this.id,
    totalTilesPlaced: totalTilesPlaced ?? this.totalTilesPlaced,
    totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
    totalCoinsEarned: totalCoinsEarned ?? this.totalCoinsEarned,
    bestScore: bestScore ?? this.bestScore,
    maxBiomeSizes: maxBiomeSizes ?? this.maxBiomeSizes,
  );
  PlayerStatsRow copyWithCompanion(PlayerStatsCompanion data) {
    return PlayerStatsRow(
      id: data.id.present ? data.id.value : this.id,
      totalTilesPlaced: data.totalTilesPlaced.present
          ? data.totalTilesPlaced.value
          : this.totalTilesPlaced,
      totalGamesPlayed: data.totalGamesPlayed.present
          ? data.totalGamesPlayed.value
          : this.totalGamesPlayed,
      totalCoinsEarned: data.totalCoinsEarned.present
          ? data.totalCoinsEarned.value
          : this.totalCoinsEarned,
      bestScore: data.bestScore.present ? data.bestScore.value : this.bestScore,
      maxBiomeSizes: data.maxBiomeSizes.present
          ? data.maxBiomeSizes.value
          : this.maxBiomeSizes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerStatsRow(')
          ..write('id: $id, ')
          ..write('totalTilesPlaced: $totalTilesPlaced, ')
          ..write('totalGamesPlayed: $totalGamesPlayed, ')
          ..write('totalCoinsEarned: $totalCoinsEarned, ')
          ..write('bestScore: $bestScore, ')
          ..write('maxBiomeSizes: $maxBiomeSizes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    totalTilesPlaced,
    totalGamesPlayed,
    totalCoinsEarned,
    bestScore,
    maxBiomeSizes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerStatsRow &&
          other.id == this.id &&
          other.totalTilesPlaced == this.totalTilesPlaced &&
          other.totalGamesPlayed == this.totalGamesPlayed &&
          other.totalCoinsEarned == this.totalCoinsEarned &&
          other.bestScore == this.bestScore &&
          other.maxBiomeSizes == this.maxBiomeSizes);
}

class PlayerStatsCompanion extends UpdateCompanion<PlayerStatsRow> {
  final Value<int> id;
  final Value<int> totalTilesPlaced;
  final Value<int> totalGamesPlayed;
  final Value<int> totalCoinsEarned;
  final Value<int> bestScore;
  final Value<String> maxBiomeSizes;
  const PlayerStatsCompanion({
    this.id = const Value.absent(),
    this.totalTilesPlaced = const Value.absent(),
    this.totalGamesPlayed = const Value.absent(),
    this.totalCoinsEarned = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.maxBiomeSizes = const Value.absent(),
  });
  PlayerStatsCompanion.insert({
    this.id = const Value.absent(),
    this.totalTilesPlaced = const Value.absent(),
    this.totalGamesPlayed = const Value.absent(),
    this.totalCoinsEarned = const Value.absent(),
    this.bestScore = const Value.absent(),
    required String maxBiomeSizes,
  }) : maxBiomeSizes = Value(maxBiomeSizes);
  static Insertable<PlayerStatsRow> custom({
    Expression<int>? id,
    Expression<int>? totalTilesPlaced,
    Expression<int>? totalGamesPlayed,
    Expression<int>? totalCoinsEarned,
    Expression<int>? bestScore,
    Expression<String>? maxBiomeSizes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (totalTilesPlaced != null) 'total_tiles_placed': totalTilesPlaced,
      if (totalGamesPlayed != null) 'total_games_played': totalGamesPlayed,
      if (totalCoinsEarned != null) 'total_coins_earned': totalCoinsEarned,
      if (bestScore != null) 'best_score': bestScore,
      if (maxBiomeSizes != null) 'max_biome_sizes': maxBiomeSizes,
    });
  }

  PlayerStatsCompanion copyWith({
    Value<int>? id,
    Value<int>? totalTilesPlaced,
    Value<int>? totalGamesPlayed,
    Value<int>? totalCoinsEarned,
    Value<int>? bestScore,
    Value<String>? maxBiomeSizes,
  }) {
    return PlayerStatsCompanion(
      id: id ?? this.id,
      totalTilesPlaced: totalTilesPlaced ?? this.totalTilesPlaced,
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalCoinsEarned: totalCoinsEarned ?? this.totalCoinsEarned,
      bestScore: bestScore ?? this.bestScore,
      maxBiomeSizes: maxBiomeSizes ?? this.maxBiomeSizes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (totalTilesPlaced.present) {
      map['total_tiles_placed'] = Variable<int>(totalTilesPlaced.value);
    }
    if (totalGamesPlayed.present) {
      map['total_games_played'] = Variable<int>(totalGamesPlayed.value);
    }
    if (totalCoinsEarned.present) {
      map['total_coins_earned'] = Variable<int>(totalCoinsEarned.value);
    }
    if (bestScore.present) {
      map['best_score'] = Variable<int>(bestScore.value);
    }
    if (maxBiomeSizes.present) {
      map['max_biome_sizes'] = Variable<String>(maxBiomeSizes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayerStatsCompanion(')
          ..write('id: $id, ')
          ..write('totalTilesPlaced: $totalTilesPlaced, ')
          ..write('totalGamesPlayed: $totalGamesPlayed, ')
          ..write('totalCoinsEarned: $totalCoinsEarned, ')
          ..write('bestScore: $bestScore, ')
          ..write('maxBiomeSizes: $maxBiomeSizes')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SetupCheckTable setupCheck = $SetupCheckTable(this);
  late final $GameSessionTable gameSession = $GameSessionTable(this);
  late final $PlayerProfileTable playerProfile = $PlayerProfileTable(this);
  late final $UpgradesTable upgrades = $UpgradesTable(this);
  late final $PermanentQuestsTable permanentQuests = $PermanentQuestsTable(
    this,
  );
  late final $DailyQuestsTable dailyQuests = $DailyQuestsTable(this);
  late final $GameSessionsTable gameSessions = $GameSessionsTable(this);
  late final $PlayerStatsTable playerStats = $PlayerStatsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    setupCheck,
    gameSession,
    playerProfile,
    upgrades,
    permanentQuests,
    dailyQuests,
    gameSessions,
    playerStats,
  ];
}

typedef $$SetupCheckTableCreateCompanionBuilder =
    SetupCheckCompanion Function({Value<int> id, required String label});
typedef $$SetupCheckTableUpdateCompanionBuilder =
    SetupCheckCompanion Function({Value<int> id, Value<String> label});

class $$SetupCheckTableFilterComposer
    extends Composer<_$AppDatabase, $SetupCheckTable> {
  $$SetupCheckTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SetupCheckTableOrderingComposer
    extends Composer<_$AppDatabase, $SetupCheckTable> {
  $$SetupCheckTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SetupCheckTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetupCheckTable> {
  $$SetupCheckTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);
}

class $$SetupCheckTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetupCheckTable,
          SetupCheckRow,
          $$SetupCheckTableFilterComposer,
          $$SetupCheckTableOrderingComposer,
          $$SetupCheckTableAnnotationComposer,
          $$SetupCheckTableCreateCompanionBuilder,
          $$SetupCheckTableUpdateCompanionBuilder,
          (
            SetupCheckRow,
            BaseReferences<_$AppDatabase, $SetupCheckTable, SetupCheckRow>,
          ),
          SetupCheckRow,
          PrefetchHooks Function()
        > {
  $$SetupCheckTableTableManager(_$AppDatabase db, $SetupCheckTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetupCheckTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetupCheckTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetupCheckTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
              }) => SetupCheckCompanion(id: id, label: label),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String label}) =>
                  SetupCheckCompanion.insert(id: id, label: label),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SetupCheckTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetupCheckTable,
      SetupCheckRow,
      $$SetupCheckTableFilterComposer,
      $$SetupCheckTableOrderingComposer,
      $$SetupCheckTableAnnotationComposer,
      $$SetupCheckTableCreateCompanionBuilder,
      $$SetupCheckTableUpdateCompanionBuilder,
      (
        SetupCheckRow,
        BaseReferences<_$AppDatabase, $SetupCheckTable, SetupCheckRow>,
      ),
      SetupCheckRow,
      PrefetchHooks Function()
    >;
typedef $$GameSessionTableCreateCompanionBuilder =
    GameSessionCompanion Function({
      Value<int> id,
      required String gridState,
      required String tileStack,
      required int coins,
      required int totalBonusTiles,
      Value<String?> lastTilePlaced,
      required int placedTilesCount,
      required bool isActive,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$GameSessionTableUpdateCompanionBuilder =
    GameSessionCompanion Function({
      Value<int> id,
      Value<String> gridState,
      Value<String> tileStack,
      Value<int> coins,
      Value<int> totalBonusTiles,
      Value<String?> lastTilePlaced,
      Value<int> placedTilesCount,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$GameSessionTableFilterComposer
    extends Composer<_$AppDatabase, $GameSessionTable> {
  $$GameSessionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gridState => $composableBuilder(
    column: $table.gridState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tileStack => $composableBuilder(
    column: $table.tileStack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBonusTiles => $composableBuilder(
    column: $table.totalBonusTiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastTilePlaced => $composableBuilder(
    column: $table.lastTilePlaced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get placedTilesCount => $composableBuilder(
    column: $table.placedTilesCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameSessionTableOrderingComposer
    extends Composer<_$AppDatabase, $GameSessionTable> {
  $$GameSessionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gridState => $composableBuilder(
    column: $table.gridState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tileStack => $composableBuilder(
    column: $table.tileStack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBonusTiles => $composableBuilder(
    column: $table.totalBonusTiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastTilePlaced => $composableBuilder(
    column: $table.lastTilePlaced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get placedTilesCount => $composableBuilder(
    column: $table.placedTilesCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameSessionTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameSessionTable> {
  $$GameSessionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get gridState =>
      $composableBuilder(column: $table.gridState, builder: (column) => column);

  GeneratedColumn<String> get tileStack =>
      $composableBuilder(column: $table.tileStack, builder: (column) => column);

  GeneratedColumn<int> get coins =>
      $composableBuilder(column: $table.coins, builder: (column) => column);

  GeneratedColumn<int> get totalBonusTiles => $composableBuilder(
    column: $table.totalBonusTiles,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastTilePlaced => $composableBuilder(
    column: $table.lastTilePlaced,
    builder: (column) => column,
  );

  GeneratedColumn<int> get placedTilesCount => $composableBuilder(
    column: $table.placedTilesCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GameSessionTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameSessionTable,
          GameSessionRow,
          $$GameSessionTableFilterComposer,
          $$GameSessionTableOrderingComposer,
          $$GameSessionTableAnnotationComposer,
          $$GameSessionTableCreateCompanionBuilder,
          $$GameSessionTableUpdateCompanionBuilder,
          (
            GameSessionRow,
            BaseReferences<_$AppDatabase, $GameSessionTable, GameSessionRow>,
          ),
          GameSessionRow,
          PrefetchHooks Function()
        > {
  $$GameSessionTableTableManager(_$AppDatabase db, $GameSessionTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameSessionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameSessionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameSessionTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> gridState = const Value.absent(),
                Value<String> tileStack = const Value.absent(),
                Value<int> coins = const Value.absent(),
                Value<int> totalBonusTiles = const Value.absent(),
                Value<String?> lastTilePlaced = const Value.absent(),
                Value<int> placedTilesCount = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GameSessionCompanion(
                id: id,
                gridState: gridState,
                tileStack: tileStack,
                coins: coins,
                totalBonusTiles: totalBonusTiles,
                lastTilePlaced: lastTilePlaced,
                placedTilesCount: placedTilesCount,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String gridState,
                required String tileStack,
                required int coins,
                required int totalBonusTiles,
                Value<String?> lastTilePlaced = const Value.absent(),
                required int placedTilesCount,
                required bool isActive,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => GameSessionCompanion.insert(
                id: id,
                gridState: gridState,
                tileStack: tileStack,
                coins: coins,
                totalBonusTiles: totalBonusTiles,
                lastTilePlaced: lastTilePlaced,
                placedTilesCount: placedTilesCount,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameSessionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameSessionTable,
      GameSessionRow,
      $$GameSessionTableFilterComposer,
      $$GameSessionTableOrderingComposer,
      $$GameSessionTableAnnotationComposer,
      $$GameSessionTableCreateCompanionBuilder,
      $$GameSessionTableUpdateCompanionBuilder,
      (
        GameSessionRow,
        BaseReferences<_$AppDatabase, $GameSessionTable, GameSessionRow>,
      ),
      GameSessionRow,
      PrefetchHooks Function()
    >;
typedef $$PlayerProfileTableCreateCompanionBuilder =
    PlayerProfileCompanion Function({
      Value<int> id,
      Value<int> coins,
      Value<int> totalTilesPlaced,
      Value<bool> isPremium,
      Value<DateTime?> lastDailyRewardDate,
    });
typedef $$PlayerProfileTableUpdateCompanionBuilder =
    PlayerProfileCompanion Function({
      Value<int> id,
      Value<int> coins,
      Value<int> totalTilesPlaced,
      Value<bool> isPremium,
      Value<DateTime?> lastDailyRewardDate,
    });

class $$PlayerProfileTableFilterComposer
    extends Composer<_$AppDatabase, $PlayerProfileTable> {
  $$PlayerProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalTilesPlaced => $composableBuilder(
    column: $table.totalTilesPlaced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastDailyRewardDate => $composableBuilder(
    column: $table.lastDailyRewardDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayerProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayerProfileTable> {
  $$PlayerProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalTilesPlaced => $composableBuilder(
    column: $table.totalTilesPlaced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastDailyRewardDate => $composableBuilder(
    column: $table.lastDailyRewardDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayerProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayerProfileTable> {
  $$PlayerProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get coins =>
      $composableBuilder(column: $table.coins, builder: (column) => column);

  GeneratedColumn<int> get totalTilesPlaced => $composableBuilder(
    column: $table.totalTilesPlaced,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPremium =>
      $composableBuilder(column: $table.isPremium, builder: (column) => column);

  GeneratedColumn<DateTime> get lastDailyRewardDate => $composableBuilder(
    column: $table.lastDailyRewardDate,
    builder: (column) => column,
  );
}

class $$PlayerProfileTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayerProfileTable,
          PlayerProfileRow,
          $$PlayerProfileTableFilterComposer,
          $$PlayerProfileTableOrderingComposer,
          $$PlayerProfileTableAnnotationComposer,
          $$PlayerProfileTableCreateCompanionBuilder,
          $$PlayerProfileTableUpdateCompanionBuilder,
          (
            PlayerProfileRow,
            BaseReferences<
              _$AppDatabase,
              $PlayerProfileTable,
              PlayerProfileRow
            >,
          ),
          PlayerProfileRow,
          PrefetchHooks Function()
        > {
  $$PlayerProfileTableTableManager(_$AppDatabase db, $PlayerProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayerProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayerProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayerProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> coins = const Value.absent(),
                Value<int> totalTilesPlaced = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
                Value<DateTime?> lastDailyRewardDate = const Value.absent(),
              }) => PlayerProfileCompanion(
                id: id,
                coins: coins,
                totalTilesPlaced: totalTilesPlaced,
                isPremium: isPremium,
                lastDailyRewardDate: lastDailyRewardDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> coins = const Value.absent(),
                Value<int> totalTilesPlaced = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
                Value<DateTime?> lastDailyRewardDate = const Value.absent(),
              }) => PlayerProfileCompanion.insert(
                id: id,
                coins: coins,
                totalTilesPlaced: totalTilesPlaced,
                isPremium: isPremium,
                lastDailyRewardDate: lastDailyRewardDate,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayerProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayerProfileTable,
      PlayerProfileRow,
      $$PlayerProfileTableFilterComposer,
      $$PlayerProfileTableOrderingComposer,
      $$PlayerProfileTableAnnotationComposer,
      $$PlayerProfileTableCreateCompanionBuilder,
      $$PlayerProfileTableUpdateCompanionBuilder,
      (
        PlayerProfileRow,
        BaseReferences<_$AppDatabase, $PlayerProfileTable, PlayerProfileRow>,
      ),
      PlayerProfileRow,
      PrefetchHooks Function()
    >;
typedef $$UpgradesTableCreateCompanionBuilder =
    UpgradesCompanion Function({
      required String id,
      required String name,
      required String effectType,
      Value<bool> isUnlocked,
      Value<int> currentLevel,
      required String unlockConditionType,
      required int unlockConditionValue,
      Value<int> rowid,
    });
typedef $$UpgradesTableUpdateCompanionBuilder =
    UpgradesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> effectType,
      Value<bool> isUnlocked,
      Value<int> currentLevel,
      Value<String> unlockConditionType,
      Value<int> unlockConditionValue,
      Value<int> rowid,
    });

class $$UpgradesTableFilterComposer
    extends Composer<_$AppDatabase, $UpgradesTable> {
  $$UpgradesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectType => $composableBuilder(
    column: $table.effectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUnlocked => $composableBuilder(
    column: $table.isUnlocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentLevel => $composableBuilder(
    column: $table.currentLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unlockConditionType => $composableBuilder(
    column: $table.unlockConditionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unlockConditionValue => $composableBuilder(
    column: $table.unlockConditionValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UpgradesTableOrderingComposer
    extends Composer<_$AppDatabase, $UpgradesTable> {
  $$UpgradesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectType => $composableBuilder(
    column: $table.effectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUnlocked => $composableBuilder(
    column: $table.isUnlocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentLevel => $composableBuilder(
    column: $table.currentLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unlockConditionType => $composableBuilder(
    column: $table.unlockConditionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unlockConditionValue => $composableBuilder(
    column: $table.unlockConditionValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UpgradesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UpgradesTable> {
  $$UpgradesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get effectType => $composableBuilder(
    column: $table.effectType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isUnlocked => $composableBuilder(
    column: $table.isUnlocked,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentLevel => $composableBuilder(
    column: $table.currentLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unlockConditionType => $composableBuilder(
    column: $table.unlockConditionType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unlockConditionValue => $composableBuilder(
    column: $table.unlockConditionValue,
    builder: (column) => column,
  );
}

class $$UpgradesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UpgradesTable,
          UpgradeRow,
          $$UpgradesTableFilterComposer,
          $$UpgradesTableOrderingComposer,
          $$UpgradesTableAnnotationComposer,
          $$UpgradesTableCreateCompanionBuilder,
          $$UpgradesTableUpdateCompanionBuilder,
          (
            UpgradeRow,
            BaseReferences<_$AppDatabase, $UpgradesTable, UpgradeRow>,
          ),
          UpgradeRow,
          PrefetchHooks Function()
        > {
  $$UpgradesTableTableManager(_$AppDatabase db, $UpgradesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UpgradesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UpgradesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UpgradesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> effectType = const Value.absent(),
                Value<bool> isUnlocked = const Value.absent(),
                Value<int> currentLevel = const Value.absent(),
                Value<String> unlockConditionType = const Value.absent(),
                Value<int> unlockConditionValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UpgradesCompanion(
                id: id,
                name: name,
                effectType: effectType,
                isUnlocked: isUnlocked,
                currentLevel: currentLevel,
                unlockConditionType: unlockConditionType,
                unlockConditionValue: unlockConditionValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String effectType,
                Value<bool> isUnlocked = const Value.absent(),
                Value<int> currentLevel = const Value.absent(),
                required String unlockConditionType,
                required int unlockConditionValue,
                Value<int> rowid = const Value.absent(),
              }) => UpgradesCompanion.insert(
                id: id,
                name: name,
                effectType: effectType,
                isUnlocked: isUnlocked,
                currentLevel: currentLevel,
                unlockConditionType: unlockConditionType,
                unlockConditionValue: unlockConditionValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UpgradesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UpgradesTable,
      UpgradeRow,
      $$UpgradesTableFilterComposer,
      $$UpgradesTableOrderingComposer,
      $$UpgradesTableAnnotationComposer,
      $$UpgradesTableCreateCompanionBuilder,
      $$UpgradesTableUpdateCompanionBuilder,
      (UpgradeRow, BaseReferences<_$AppDatabase, $UpgradesTable, UpgradeRow>),
      UpgradeRow,
      PrefetchHooks Function()
    >;
typedef $$PermanentQuestsTableCreateCompanionBuilder =
    PermanentQuestsCompanion Function({
      required String id,
      required String category,
      required String description,
      required int targetValue,
      Value<int> currentValue,
      Value<bool> isCompleted,
      required String rewardType,
      required int rewardValue,
      Value<String?> nextQuestId,
      Value<int> rowid,
    });
typedef $$PermanentQuestsTableUpdateCompanionBuilder =
    PermanentQuestsCompanion Function({
      Value<String> id,
      Value<String> category,
      Value<String> description,
      Value<int> targetValue,
      Value<int> currentValue,
      Value<bool> isCompleted,
      Value<String> rewardType,
      Value<int> rewardValue,
      Value<String?> nextQuestId,
      Value<int> rowid,
    });

class $$PermanentQuestsTableFilterComposer
    extends Composer<_$AppDatabase, $PermanentQuestsTable> {
  $$PermanentQuestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rewardType => $composableBuilder(
    column: $table.rewardType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rewardValue => $composableBuilder(
    column: $table.rewardValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextQuestId => $composableBuilder(
    column: $table.nextQuestId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PermanentQuestsTableOrderingComposer
    extends Composer<_$AppDatabase, $PermanentQuestsTable> {
  $$PermanentQuestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rewardType => $composableBuilder(
    column: $table.rewardType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rewardValue => $composableBuilder(
    column: $table.rewardValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextQuestId => $composableBuilder(
    column: $table.nextQuestId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PermanentQuestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PermanentQuestsTable> {
  $$PermanentQuestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rewardType => $composableBuilder(
    column: $table.rewardType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rewardValue => $composableBuilder(
    column: $table.rewardValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextQuestId => $composableBuilder(
    column: $table.nextQuestId,
    builder: (column) => column,
  );
}

class $$PermanentQuestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PermanentQuestsTable,
          PermanentQuestRow,
          $$PermanentQuestsTableFilterComposer,
          $$PermanentQuestsTableOrderingComposer,
          $$PermanentQuestsTableAnnotationComposer,
          $$PermanentQuestsTableCreateCompanionBuilder,
          $$PermanentQuestsTableUpdateCompanionBuilder,
          (
            PermanentQuestRow,
            BaseReferences<
              _$AppDatabase,
              $PermanentQuestsTable,
              PermanentQuestRow
            >,
          ),
          PermanentQuestRow,
          PrefetchHooks Function()
        > {
  $$PermanentQuestsTableTableManager(
    _$AppDatabase db,
    $PermanentQuestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PermanentQuestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PermanentQuestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PermanentQuestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> targetValue = const Value.absent(),
                Value<int> currentValue = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<String> rewardType = const Value.absent(),
                Value<int> rewardValue = const Value.absent(),
                Value<String?> nextQuestId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PermanentQuestsCompanion(
                id: id,
                category: category,
                description: description,
                targetValue: targetValue,
                currentValue: currentValue,
                isCompleted: isCompleted,
                rewardType: rewardType,
                rewardValue: rewardValue,
                nextQuestId: nextQuestId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String category,
                required String description,
                required int targetValue,
                Value<int> currentValue = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                required String rewardType,
                required int rewardValue,
                Value<String?> nextQuestId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PermanentQuestsCompanion.insert(
                id: id,
                category: category,
                description: description,
                targetValue: targetValue,
                currentValue: currentValue,
                isCompleted: isCompleted,
                rewardType: rewardType,
                rewardValue: rewardValue,
                nextQuestId: nextQuestId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PermanentQuestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PermanentQuestsTable,
      PermanentQuestRow,
      $$PermanentQuestsTableFilterComposer,
      $$PermanentQuestsTableOrderingComposer,
      $$PermanentQuestsTableAnnotationComposer,
      $$PermanentQuestsTableCreateCompanionBuilder,
      $$PermanentQuestsTableUpdateCompanionBuilder,
      (
        PermanentQuestRow,
        BaseReferences<_$AppDatabase, $PermanentQuestsTable, PermanentQuestRow>,
      ),
      PermanentQuestRow,
      PrefetchHooks Function()
    >;
typedef $$DailyQuestsTableCreateCompanionBuilder =
    DailyQuestsCompanion Function({
      Value<int> id,
      required DateTime date,
      required String questPoolIds,
      required String completedIds,
      required String progressByQuestId,
    });
typedef $$DailyQuestsTableUpdateCompanionBuilder =
    DailyQuestsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> questPoolIds,
      Value<String> completedIds,
      Value<String> progressByQuestId,
    });

class $$DailyQuestsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyQuestsTable> {
  $$DailyQuestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questPoolIds => $composableBuilder(
    column: $table.questPoolIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedIds => $composableBuilder(
    column: $table.completedIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get progressByQuestId => $composableBuilder(
    column: $table.progressByQuestId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyQuestsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyQuestsTable> {
  $$DailyQuestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questPoolIds => $composableBuilder(
    column: $table.questPoolIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedIds => $composableBuilder(
    column: $table.completedIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get progressByQuestId => $composableBuilder(
    column: $table.progressByQuestId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyQuestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyQuestsTable> {
  $$DailyQuestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get questPoolIds => $composableBuilder(
    column: $table.questPoolIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedIds => $composableBuilder(
    column: $table.completedIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get progressByQuestId => $composableBuilder(
    column: $table.progressByQuestId,
    builder: (column) => column,
  );
}

class $$DailyQuestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyQuestsTable,
          DailyQuestRow,
          $$DailyQuestsTableFilterComposer,
          $$DailyQuestsTableOrderingComposer,
          $$DailyQuestsTableAnnotationComposer,
          $$DailyQuestsTableCreateCompanionBuilder,
          $$DailyQuestsTableUpdateCompanionBuilder,
          (
            DailyQuestRow,
            BaseReferences<_$AppDatabase, $DailyQuestsTable, DailyQuestRow>,
          ),
          DailyQuestRow,
          PrefetchHooks Function()
        > {
  $$DailyQuestsTableTableManager(_$AppDatabase db, $DailyQuestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyQuestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyQuestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyQuestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> questPoolIds = const Value.absent(),
                Value<String> completedIds = const Value.absent(),
                Value<String> progressByQuestId = const Value.absent(),
              }) => DailyQuestsCompanion(
                id: id,
                date: date,
                questPoolIds: questPoolIds,
                completedIds: completedIds,
                progressByQuestId: progressByQuestId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required String questPoolIds,
                required String completedIds,
                required String progressByQuestId,
              }) => DailyQuestsCompanion.insert(
                id: id,
                date: date,
                questPoolIds: questPoolIds,
                completedIds: completedIds,
                progressByQuestId: progressByQuestId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyQuestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyQuestsTable,
      DailyQuestRow,
      $$DailyQuestsTableFilterComposer,
      $$DailyQuestsTableOrderingComposer,
      $$DailyQuestsTableAnnotationComposer,
      $$DailyQuestsTableCreateCompanionBuilder,
      $$DailyQuestsTableUpdateCompanionBuilder,
      (
        DailyQuestRow,
        BaseReferences<_$AppDatabase, $DailyQuestsTable, DailyQuestRow>,
      ),
      DailyQuestRow,
      PrefetchHooks Function()
    >;
typedef $$GameSessionsTableCreateCompanionBuilder =
    GameSessionsCompanion Function({
      Value<int> id,
      Value<bool> isActive,
      required int tilesRemaining,
      required String selectedUpgradeIds,
      Value<int> coinsEarned,
      Value<int> tilesPlaced,
      required String gridState,
      required String tileStack,
      Value<String?> lastTilePlaced,
      required int seed,
    });
typedef $$GameSessionsTableUpdateCompanionBuilder =
    GameSessionsCompanion Function({
      Value<int> id,
      Value<bool> isActive,
      Value<int> tilesRemaining,
      Value<String> selectedUpgradeIds,
      Value<int> coinsEarned,
      Value<int> tilesPlaced,
      Value<String> gridState,
      Value<String> tileStack,
      Value<String?> lastTilePlaced,
      Value<int> seed,
    });

class $$GameSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $GameSessionsTable> {
  $$GameSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tilesRemaining => $composableBuilder(
    column: $table.tilesRemaining,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedUpgradeIds => $composableBuilder(
    column: $table.selectedUpgradeIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coinsEarned => $composableBuilder(
    column: $table.coinsEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tilesPlaced => $composableBuilder(
    column: $table.tilesPlaced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gridState => $composableBuilder(
    column: $table.gridState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tileStack => $composableBuilder(
    column: $table.tileStack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastTilePlaced => $composableBuilder(
    column: $table.lastTilePlaced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $GameSessionsTable> {
  $$GameSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tilesRemaining => $composableBuilder(
    column: $table.tilesRemaining,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedUpgradeIds => $composableBuilder(
    column: $table.selectedUpgradeIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coinsEarned => $composableBuilder(
    column: $table.coinsEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tilesPlaced => $composableBuilder(
    column: $table.tilesPlaced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gridState => $composableBuilder(
    column: $table.gridState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tileStack => $composableBuilder(
    column: $table.tileStack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastTilePlaced => $composableBuilder(
    column: $table.lastTilePlaced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameSessionsTable> {
  $$GameSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get tilesRemaining => $composableBuilder(
    column: $table.tilesRemaining,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedUpgradeIds => $composableBuilder(
    column: $table.selectedUpgradeIds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get coinsEarned => $composableBuilder(
    column: $table.coinsEarned,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tilesPlaced => $composableBuilder(
    column: $table.tilesPlaced,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gridState =>
      $composableBuilder(column: $table.gridState, builder: (column) => column);

  GeneratedColumn<String> get tileStack =>
      $composableBuilder(column: $table.tileStack, builder: (column) => column);

  GeneratedColumn<String> get lastTilePlaced => $composableBuilder(
    column: $table.lastTilePlaced,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seed =>
      $composableBuilder(column: $table.seed, builder: (column) => column);
}

class $$GameSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameSessionsTable,
          MetaGameSessionRow,
          $$GameSessionsTableFilterComposer,
          $$GameSessionsTableOrderingComposer,
          $$GameSessionsTableAnnotationComposer,
          $$GameSessionsTableCreateCompanionBuilder,
          $$GameSessionsTableUpdateCompanionBuilder,
          (
            MetaGameSessionRow,
            BaseReferences<
              _$AppDatabase,
              $GameSessionsTable,
              MetaGameSessionRow
            >,
          ),
          MetaGameSessionRow,
          PrefetchHooks Function()
        > {
  $$GameSessionsTableTableManager(_$AppDatabase db, $GameSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> tilesRemaining = const Value.absent(),
                Value<String> selectedUpgradeIds = const Value.absent(),
                Value<int> coinsEarned = const Value.absent(),
                Value<int> tilesPlaced = const Value.absent(),
                Value<String> gridState = const Value.absent(),
                Value<String> tileStack = const Value.absent(),
                Value<String?> lastTilePlaced = const Value.absent(),
                Value<int> seed = const Value.absent(),
              }) => GameSessionsCompanion(
                id: id,
                isActive: isActive,
                tilesRemaining: tilesRemaining,
                selectedUpgradeIds: selectedUpgradeIds,
                coinsEarned: coinsEarned,
                tilesPlaced: tilesPlaced,
                gridState: gridState,
                tileStack: tileStack,
                lastTilePlaced: lastTilePlaced,
                seed: seed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required int tilesRemaining,
                required String selectedUpgradeIds,
                Value<int> coinsEarned = const Value.absent(),
                Value<int> tilesPlaced = const Value.absent(),
                required String gridState,
                required String tileStack,
                Value<String?> lastTilePlaced = const Value.absent(),
                required int seed,
              }) => GameSessionsCompanion.insert(
                id: id,
                isActive: isActive,
                tilesRemaining: tilesRemaining,
                selectedUpgradeIds: selectedUpgradeIds,
                coinsEarned: coinsEarned,
                tilesPlaced: tilesPlaced,
                gridState: gridState,
                tileStack: tileStack,
                lastTilePlaced: lastTilePlaced,
                seed: seed,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameSessionsTable,
      MetaGameSessionRow,
      $$GameSessionsTableFilterComposer,
      $$GameSessionsTableOrderingComposer,
      $$GameSessionsTableAnnotationComposer,
      $$GameSessionsTableCreateCompanionBuilder,
      $$GameSessionsTableUpdateCompanionBuilder,
      (
        MetaGameSessionRow,
        BaseReferences<_$AppDatabase, $GameSessionsTable, MetaGameSessionRow>,
      ),
      MetaGameSessionRow,
      PrefetchHooks Function()
    >;
typedef $$PlayerStatsTableCreateCompanionBuilder =
    PlayerStatsCompanion Function({
      Value<int> id,
      Value<int> totalTilesPlaced,
      Value<int> totalGamesPlayed,
      Value<int> totalCoinsEarned,
      Value<int> bestScore,
      required String maxBiomeSizes,
    });
typedef $$PlayerStatsTableUpdateCompanionBuilder =
    PlayerStatsCompanion Function({
      Value<int> id,
      Value<int> totalTilesPlaced,
      Value<int> totalGamesPlayed,
      Value<int> totalCoinsEarned,
      Value<int> bestScore,
      Value<String> maxBiomeSizes,
    });

class $$PlayerStatsTableFilterComposer
    extends Composer<_$AppDatabase, $PlayerStatsTable> {
  $$PlayerStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalTilesPlaced => $composableBuilder(
    column: $table.totalTilesPlaced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalGamesPlayed => $composableBuilder(
    column: $table.totalGamesPlayed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCoinsEarned => $composableBuilder(
    column: $table.totalCoinsEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get maxBiomeSizes => $composableBuilder(
    column: $table.maxBiomeSizes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayerStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayerStatsTable> {
  $$PlayerStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalTilesPlaced => $composableBuilder(
    column: $table.totalTilesPlaced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalGamesPlayed => $composableBuilder(
    column: $table.totalGamesPlayed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCoinsEarned => $composableBuilder(
    column: $table.totalCoinsEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get maxBiomeSizes => $composableBuilder(
    column: $table.maxBiomeSizes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayerStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayerStatsTable> {
  $$PlayerStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get totalTilesPlaced => $composableBuilder(
    column: $table.totalTilesPlaced,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalGamesPlayed => $composableBuilder(
    column: $table.totalGamesPlayed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCoinsEarned => $composableBuilder(
    column: $table.totalCoinsEarned,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bestScore =>
      $composableBuilder(column: $table.bestScore, builder: (column) => column);

  GeneratedColumn<String> get maxBiomeSizes => $composableBuilder(
    column: $table.maxBiomeSizes,
    builder: (column) => column,
  );
}

class $$PlayerStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayerStatsTable,
          PlayerStatsRow,
          $$PlayerStatsTableFilterComposer,
          $$PlayerStatsTableOrderingComposer,
          $$PlayerStatsTableAnnotationComposer,
          $$PlayerStatsTableCreateCompanionBuilder,
          $$PlayerStatsTableUpdateCompanionBuilder,
          (
            PlayerStatsRow,
            BaseReferences<_$AppDatabase, $PlayerStatsTable, PlayerStatsRow>,
          ),
          PlayerStatsRow,
          PrefetchHooks Function()
        > {
  $$PlayerStatsTableTableManager(_$AppDatabase db, $PlayerStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayerStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayerStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayerStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> totalTilesPlaced = const Value.absent(),
                Value<int> totalGamesPlayed = const Value.absent(),
                Value<int> totalCoinsEarned = const Value.absent(),
                Value<int> bestScore = const Value.absent(),
                Value<String> maxBiomeSizes = const Value.absent(),
              }) => PlayerStatsCompanion(
                id: id,
                totalTilesPlaced: totalTilesPlaced,
                totalGamesPlayed: totalGamesPlayed,
                totalCoinsEarned: totalCoinsEarned,
                bestScore: bestScore,
                maxBiomeSizes: maxBiomeSizes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> totalTilesPlaced = const Value.absent(),
                Value<int> totalGamesPlayed = const Value.absent(),
                Value<int> totalCoinsEarned = const Value.absent(),
                Value<int> bestScore = const Value.absent(),
                required String maxBiomeSizes,
              }) => PlayerStatsCompanion.insert(
                id: id,
                totalTilesPlaced: totalTilesPlaced,
                totalGamesPlayed: totalGamesPlayed,
                totalCoinsEarned: totalCoinsEarned,
                bestScore: bestScore,
                maxBiomeSizes: maxBiomeSizes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayerStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayerStatsTable,
      PlayerStatsRow,
      $$PlayerStatsTableFilterComposer,
      $$PlayerStatsTableOrderingComposer,
      $$PlayerStatsTableAnnotationComposer,
      $$PlayerStatsTableCreateCompanionBuilder,
      $$PlayerStatsTableUpdateCompanionBuilder,
      (
        PlayerStatsRow,
        BaseReferences<_$AppDatabase, $PlayerStatsTable, PlayerStatsRow>,
      ),
      PlayerStatsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SetupCheckTableTableManager get setupCheck =>
      $$SetupCheckTableTableManager(_db, _db.setupCheck);
  $$GameSessionTableTableManager get gameSession =>
      $$GameSessionTableTableManager(_db, _db.gameSession);
  $$PlayerProfileTableTableManager get playerProfile =>
      $$PlayerProfileTableTableManager(_db, _db.playerProfile);
  $$UpgradesTableTableManager get upgrades =>
      $$UpgradesTableTableManager(_db, _db.upgrades);
  $$PermanentQuestsTableTableManager get permanentQuests =>
      $$PermanentQuestsTableTableManager(_db, _db.permanentQuests);
  $$DailyQuestsTableTableManager get dailyQuests =>
      $$DailyQuestsTableTableManager(_db, _db.dailyQuests);
  $$GameSessionsTableTableManager get gameSessions =>
      $$GameSessionsTableTableManager(_db, _db.gameSessions);
  $$PlayerStatsTableTableManager get playerStats =>
      $$PlayerStatsTableTableManager(_db, _db.playerStats);
}
