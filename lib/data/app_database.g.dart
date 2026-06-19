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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SetupCheckTable setupCheck = $SetupCheckTable(this);
  late final $GameSessionTable gameSession = $GameSessionTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [setupCheck, gameSession];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SetupCheckTableTableManager get setupCheck =>
      $$SetupCheckTableTableManager(_db, _db.setupCheck);
  $$GameSessionTableTableManager get gameSession =>
      $$GameSessionTableTableManager(_db, _db.gameSession);
}
