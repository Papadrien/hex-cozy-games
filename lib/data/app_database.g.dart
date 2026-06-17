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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SetupCheckTable setupCheck = $SetupCheckTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [setupCheck];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SetupCheckTableTableManager get setupCheck =>
      $$SetupCheckTableTableManager(_db, _db.setupCheck);
}
