// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_database.dart';

// ignore_for_file: type=lint
class $TaskCardsTable extends TaskCards
    with TableInfo<$TaskCardsTable, TaskCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zIndexMeta = const VerificationMeta('zIndex');
  @override
  late final GeneratedColumn<int> zIndex = GeneratedColumn<int>(
    'z_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CardStatus>($TaskCardsTable.$converterstatus);
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carriedOverMeta = const VerificationMeta(
    'carriedOver',
  );
  @override
  late final GeneratedColumn<bool> carriedOver = GeneratedColumn<bool>(
    'carried_over',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("carried_over" IN (0, 1))',
    ),
  );
  static const VerificationMeta _originalDayKeyMeta = const VerificationMeta(
    'originalDayKey',
  );
  @override
  late final GeneratedColumn<String> originalDayKey = GeneratedColumn<String>(
    'original_day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTimeMeta = const VerificationMeta(
    'eventTime',
  );
  @override
  late final GeneratedColumn<String> eventTime = GeneratedColumn<String>(
    'event_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardTimePrecision?, String>
  eventTimePrecision =
      GeneratedColumn<String>(
        'event_time_precision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CardTimePrecision?>(
        $TaskCardsTable.$convertereventTimePrecisionn,
      );
  static const VerificationMeta _eventTimePendingMeta = const VerificationMeta(
    'eventTimePending',
  );
  @override
  late final GeneratedColumn<bool> eventTimePending = GeneratedColumn<bool>(
    'event_time_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("event_time_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dueTimeMeta = const VerificationMeta(
    'dueTime',
  );
  @override
  late final GeneratedColumn<String> dueTime = GeneratedColumn<String>(
    'due_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardTimePrecision?, String>
  dueTimePrecision =
      GeneratedColumn<String>(
        'due_time_precision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CardTimePrecision?>(
        $TaskCardsTable.$converterdueTimePrecisionn,
      );
  static const VerificationMeta _dueTimePendingMeta = const VerificationMeta(
    'dueTimePending',
  );
  @override
  late final GeneratedColumn<bool> dueTimePending = GeneratedColumn<bool>(
    'due_time_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("due_time_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dayKey,
    title,
    note,
    x,
    y,
    width,
    height,
    zIndex,
    colorArgb,
    status,
    completedAt,
    carriedOver,
    originalDayKey,
    deletedAt,
    createdAt,
    updatedAt,
    eventTime,
    eventTimePrecision,
    eventTimePending,
    dueTime,
    dueTimePrecision,
    dueTimePending,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('z_index')) {
      context.handle(
        _zIndexMeta,
        zIndex.isAcceptableOrUnknown(data['z_index']!, _zIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_zIndexMeta);
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    } else if (isInserting) {
      context.missing(_colorArgbMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('carried_over')) {
      context.handle(
        _carriedOverMeta,
        carriedOver.isAcceptableOrUnknown(
          data['carried_over']!,
          _carriedOverMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_carriedOverMeta);
    }
    if (data.containsKey('original_day_key')) {
      context.handle(
        _originalDayKeyMeta,
        originalDayKey.isAcceptableOrUnknown(
          data['original_day_key']!,
          _originalDayKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalDayKeyMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
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
    if (data.containsKey('event_time')) {
      context.handle(
        _eventTimeMeta,
        eventTime.isAcceptableOrUnknown(data['event_time']!, _eventTimeMeta),
      );
    }
    if (data.containsKey('event_time_pending')) {
      context.handle(
        _eventTimePendingMeta,
        eventTimePending.isAcceptableOrUnknown(
          data['event_time_pending']!,
          _eventTimePendingMeta,
        ),
      );
    }
    if (data.containsKey('due_time')) {
      context.handle(
        _dueTimeMeta,
        dueTime.isAcceptableOrUnknown(data['due_time']!, _dueTimeMeta),
      );
    }
    if (data.containsKey('due_time_pending')) {
      context.handle(
        _dueTimePendingMeta,
        dueTimePending.isAcceptableOrUnknown(
          data['due_time_pending']!,
          _dueTimePendingMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskCardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      zIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}z_index'],
      )!,
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      )!,
      status: $TaskCardsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      carriedOver: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}carried_over'],
      )!,
      originalDayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_day_key'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      eventTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_time'],
      ),
      eventTimePrecision: $TaskCardsTable.$convertereventTimePrecisionn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}event_time_precision'],
        ),
      ),
      eventTimePending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}event_time_pending'],
      )!,
      dueTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_time'],
      ),
      dueTimePrecision: $TaskCardsTable.$converterdueTimePrecisionn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}due_time_precision'],
        ),
      ),
      dueTimePending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}due_time_pending'],
      )!,
    );
  }

  @override
  $TaskCardsTable createAlias(String alias) {
    return $TaskCardsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CardStatus, String, String> $converterstatus =
      const EnumNameConverter<CardStatus>(CardStatus.values);
  static JsonTypeConverter2<CardTimePrecision, String, String>
  $convertereventTimePrecision = const EnumNameConverter<CardTimePrecision>(
    CardTimePrecision.values,
  );
  static JsonTypeConverter2<CardTimePrecision?, String?, String?>
  $convertereventTimePrecisionn = JsonTypeConverter2.asNullable(
    $convertereventTimePrecision,
  );
  static JsonTypeConverter2<CardTimePrecision, String, String>
  $converterdueTimePrecision = const EnumNameConverter<CardTimePrecision>(
    CardTimePrecision.values,
  );
  static JsonTypeConverter2<CardTimePrecision?, String?, String?>
  $converterdueTimePrecisionn = JsonTypeConverter2.asNullable(
    $converterdueTimePrecision,
  );
}

class TaskCardRow extends DataClass implements Insertable<TaskCardRow> {
  final String id;
  final String dayKey;
  final String title;
  final String? note;
  final double x;
  final double y;
  final double width;
  final double height;
  final int zIndex;
  final int colorArgb;
  final CardStatus status;
  final int? completedAt;
  final bool carriedOver;
  final String originalDayKey;
  final int? deletedAt;
  final int createdAt;
  final int updatedAt;
  final String? eventTime;
  final CardTimePrecision? eventTimePrecision;
  final bool eventTimePending;
  final String? dueTime;
  final CardTimePrecision? dueTimePrecision;
  final bool dueTimePending;
  const TaskCardRow({
    required this.id,
    required this.dayKey,
    required this.title,
    this.note,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
    required this.colorArgb,
    required this.status,
    this.completedAt,
    required this.carriedOver,
    required this.originalDayKey,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.eventTime,
    this.eventTimePrecision,
    required this.eventTimePending,
    this.dueTime,
    this.dueTimePrecision,
    required this.dueTimePending,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['day_key'] = Variable<String>(dayKey);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    map['z_index'] = Variable<int>(zIndex);
    map['color_argb'] = Variable<int>(colorArgb);
    {
      map['status'] = Variable<String>(
        $TaskCardsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    map['carried_over'] = Variable<bool>(carriedOver);
    map['original_day_key'] = Variable<String>(originalDayKey);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || eventTime != null) {
      map['event_time'] = Variable<String>(eventTime);
    }
    if (!nullToAbsent || eventTimePrecision != null) {
      map['event_time_precision'] = Variable<String>(
        $TaskCardsTable.$convertereventTimePrecisionn.toSql(eventTimePrecision),
      );
    }
    map['event_time_pending'] = Variable<bool>(eventTimePending);
    if (!nullToAbsent || dueTime != null) {
      map['due_time'] = Variable<String>(dueTime);
    }
    if (!nullToAbsent || dueTimePrecision != null) {
      map['due_time_precision'] = Variable<String>(
        $TaskCardsTable.$converterdueTimePrecisionn.toSql(dueTimePrecision),
      );
    }
    map['due_time_pending'] = Variable<bool>(dueTimePending);
    return map;
  }

  TaskCardsCompanion toCompanion(bool nullToAbsent) {
    return TaskCardsCompanion(
      id: Value(id),
      dayKey: Value(dayKey),
      title: Value(title),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      x: Value(x),
      y: Value(y),
      width: Value(width),
      height: Value(height),
      zIndex: Value(zIndex),
      colorArgb: Value(colorArgb),
      status: Value(status),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      carriedOver: Value(carriedOver),
      originalDayKey: Value(originalDayKey),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      eventTime: eventTime == null && nullToAbsent
          ? const Value.absent()
          : Value(eventTime),
      eventTimePrecision: eventTimePrecision == null && nullToAbsent
          ? const Value.absent()
          : Value(eventTimePrecision),
      eventTimePending: Value(eventTimePending),
      dueTime: dueTime == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTime),
      dueTimePrecision: dueTimePrecision == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTimePrecision),
      dueTimePending: Value(dueTimePending),
    );
  }

  factory TaskCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskCardRow(
      id: serializer.fromJson<String>(json['id']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String?>(json['note']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      zIndex: serializer.fromJson<int>(json['zIndex']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      status: $TaskCardsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      carriedOver: serializer.fromJson<bool>(json['carriedOver']),
      originalDayKey: serializer.fromJson<String>(json['originalDayKey']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      eventTime: serializer.fromJson<String?>(json['eventTime']),
      eventTimePrecision: $TaskCardsTable.$convertereventTimePrecisionn
          .fromJson(serializer.fromJson<String?>(json['eventTimePrecision'])),
      eventTimePending: serializer.fromJson<bool>(json['eventTimePending']),
      dueTime: serializer.fromJson<String?>(json['dueTime']),
      dueTimePrecision: $TaskCardsTable.$converterdueTimePrecisionn.fromJson(
        serializer.fromJson<String?>(json['dueTimePrecision']),
      ),
      dueTimePending: serializer.fromJson<bool>(json['dueTimePending']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dayKey': serializer.toJson<String>(dayKey),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String?>(note),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'zIndex': serializer.toJson<int>(zIndex),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'status': serializer.toJson<String>(
        $TaskCardsTable.$converterstatus.toJson(status),
      ),
      'completedAt': serializer.toJson<int?>(completedAt),
      'carriedOver': serializer.toJson<bool>(carriedOver),
      'originalDayKey': serializer.toJson<String>(originalDayKey),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'eventTime': serializer.toJson<String?>(eventTime),
      'eventTimePrecision': serializer.toJson<String?>(
        $TaskCardsTable.$convertereventTimePrecisionn.toJson(
          eventTimePrecision,
        ),
      ),
      'eventTimePending': serializer.toJson<bool>(eventTimePending),
      'dueTime': serializer.toJson<String?>(dueTime),
      'dueTimePrecision': serializer.toJson<String?>(
        $TaskCardsTable.$converterdueTimePrecisionn.toJson(dueTimePrecision),
      ),
      'dueTimePending': serializer.toJson<bool>(dueTimePending),
    };
  }

  TaskCardRow copyWith({
    String? id,
    String? dayKey,
    String? title,
    Value<String?> note = const Value.absent(),
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    int? colorArgb,
    CardStatus? status,
    Value<int?> completedAt = const Value.absent(),
    bool? carriedOver,
    String? originalDayKey,
    Value<int?> deletedAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<String?> eventTime = const Value.absent(),
    Value<CardTimePrecision?> eventTimePrecision = const Value.absent(),
    bool? eventTimePending,
    Value<String?> dueTime = const Value.absent(),
    Value<CardTimePrecision?> dueTimePrecision = const Value.absent(),
    bool? dueTimePending,
  }) => TaskCardRow(
    id: id ?? this.id,
    dayKey: dayKey ?? this.dayKey,
    title: title ?? this.title,
    note: note.present ? note.value : this.note,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    zIndex: zIndex ?? this.zIndex,
    colorArgb: colorArgb ?? this.colorArgb,
    status: status ?? this.status,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    carriedOver: carriedOver ?? this.carriedOver,
    originalDayKey: originalDayKey ?? this.originalDayKey,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    eventTime: eventTime.present ? eventTime.value : this.eventTime,
    eventTimePrecision: eventTimePrecision.present
        ? eventTimePrecision.value
        : this.eventTimePrecision,
    eventTimePending: eventTimePending ?? this.eventTimePending,
    dueTime: dueTime.present ? dueTime.value : this.dueTime,
    dueTimePrecision: dueTimePrecision.present
        ? dueTimePrecision.value
        : this.dueTimePrecision,
    dueTimePending: dueTimePending ?? this.dueTimePending,
  );
  TaskCardRow copyWithCompanion(TaskCardsCompanion data) {
    return TaskCardRow(
      id: data.id.present ? data.id.value : this.id,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      zIndex: data.zIndex.present ? data.zIndex.value : this.zIndex,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      status: data.status.present ? data.status.value : this.status,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      carriedOver: data.carriedOver.present
          ? data.carriedOver.value
          : this.carriedOver,
      originalDayKey: data.originalDayKey.present
          ? data.originalDayKey.value
          : this.originalDayKey,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      eventTime: data.eventTime.present ? data.eventTime.value : this.eventTime,
      eventTimePrecision: data.eventTimePrecision.present
          ? data.eventTimePrecision.value
          : this.eventTimePrecision,
      eventTimePending: data.eventTimePending.present
          ? data.eventTimePending.value
          : this.eventTimePending,
      dueTime: data.dueTime.present ? data.dueTime.value : this.dueTime,
      dueTimePrecision: data.dueTimePrecision.present
          ? data.dueTimePrecision.value
          : this.dueTimePrecision,
      dueTimePending: data.dueTimePending.present
          ? data.dueTimePending.value
          : this.dueTimePending,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskCardRow(')
          ..write('id: $id, ')
          ..write('dayKey: $dayKey, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('zIndex: $zIndex, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('carriedOver: $carriedOver, ')
          ..write('originalDayKey: $originalDayKey, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('eventTime: $eventTime, ')
          ..write('eventTimePrecision: $eventTimePrecision, ')
          ..write('eventTimePending: $eventTimePending, ')
          ..write('dueTime: $dueTime, ')
          ..write('dueTimePrecision: $dueTimePrecision, ')
          ..write('dueTimePending: $dueTimePending')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    dayKey,
    title,
    note,
    x,
    y,
    width,
    height,
    zIndex,
    colorArgb,
    status,
    completedAt,
    carriedOver,
    originalDayKey,
    deletedAt,
    createdAt,
    updatedAt,
    eventTime,
    eventTimePrecision,
    eventTimePending,
    dueTime,
    dueTimePrecision,
    dueTimePending,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskCardRow &&
          other.id == this.id &&
          other.dayKey == this.dayKey &&
          other.title == this.title &&
          other.note == this.note &&
          other.x == this.x &&
          other.y == this.y &&
          other.width == this.width &&
          other.height == this.height &&
          other.zIndex == this.zIndex &&
          other.colorArgb == this.colorArgb &&
          other.status == this.status &&
          other.completedAt == this.completedAt &&
          other.carriedOver == this.carriedOver &&
          other.originalDayKey == this.originalDayKey &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.eventTime == this.eventTime &&
          other.eventTimePrecision == this.eventTimePrecision &&
          other.eventTimePending == this.eventTimePending &&
          other.dueTime == this.dueTime &&
          other.dueTimePrecision == this.dueTimePrecision &&
          other.dueTimePending == this.dueTimePending);
}

class TaskCardsCompanion extends UpdateCompanion<TaskCardRow> {
  final Value<String> id;
  final Value<String> dayKey;
  final Value<String> title;
  final Value<String?> note;
  final Value<double> x;
  final Value<double> y;
  final Value<double> width;
  final Value<double> height;
  final Value<int> zIndex;
  final Value<int> colorArgb;
  final Value<CardStatus> status;
  final Value<int?> completedAt;
  final Value<bool> carriedOver;
  final Value<String> originalDayKey;
  final Value<int?> deletedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> eventTime;
  final Value<CardTimePrecision?> eventTimePrecision;
  final Value<bool> eventTimePending;
  final Value<String?> dueTime;
  final Value<CardTimePrecision?> dueTimePrecision;
  final Value<bool> dueTimePending;
  final Value<int> rowid;
  const TaskCardsCompanion({
    this.id = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.zIndex = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.carriedOver = const Value.absent(),
    this.originalDayKey = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.eventTime = const Value.absent(),
    this.eventTimePrecision = const Value.absent(),
    this.eventTimePending = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.dueTimePrecision = const Value.absent(),
    this.dueTimePending = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskCardsCompanion.insert({
    required String id,
    required String dayKey,
    required String title,
    this.note = const Value.absent(),
    required double x,
    required double y,
    required double width,
    required double height,
    required int zIndex,
    required int colorArgb,
    required CardStatus status,
    this.completedAt = const Value.absent(),
    required bool carriedOver,
    required String originalDayKey,
    this.deletedAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.eventTime = const Value.absent(),
    this.eventTimePrecision = const Value.absent(),
    this.eventTimePending = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.dueTimePrecision = const Value.absent(),
    this.dueTimePending = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dayKey = Value(dayKey),
       title = Value(title),
       x = Value(x),
       y = Value(y),
       width = Value(width),
       height = Value(height),
       zIndex = Value(zIndex),
       colorArgb = Value(colorArgb),
       status = Value(status),
       carriedOver = Value(carriedOver),
       originalDayKey = Value(originalDayKey),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskCardRow> custom({
    Expression<String>? id,
    Expression<String>? dayKey,
    Expression<String>? title,
    Expression<String>? note,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? width,
    Expression<double>? height,
    Expression<int>? zIndex,
    Expression<int>? colorArgb,
    Expression<String>? status,
    Expression<int>? completedAt,
    Expression<bool>? carriedOver,
    Expression<String>? originalDayKey,
    Expression<int>? deletedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? eventTime,
    Expression<String>? eventTimePrecision,
    Expression<bool>? eventTimePending,
    Expression<String>? dueTime,
    Expression<String>? dueTimePrecision,
    Expression<bool>? dueTimePending,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayKey != null) 'day_key': dayKey,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (zIndex != null) 'z_index': zIndex,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (status != null) 'status': status,
      if (completedAt != null) 'completed_at': completedAt,
      if (carriedOver != null) 'carried_over': carriedOver,
      if (originalDayKey != null) 'original_day_key': originalDayKey,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (eventTime != null) 'event_time': eventTime,
      if (eventTimePrecision != null)
        'event_time_precision': eventTimePrecision,
      if (eventTimePending != null) 'event_time_pending': eventTimePending,
      if (dueTime != null) 'due_time': dueTime,
      if (dueTimePrecision != null) 'due_time_precision': dueTimePrecision,
      if (dueTimePending != null) 'due_time_pending': dueTimePending,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskCardsCompanion copyWith({
    Value<String>? id,
    Value<String>? dayKey,
    Value<String>? title,
    Value<String?>? note,
    Value<double>? x,
    Value<double>? y,
    Value<double>? width,
    Value<double>? height,
    Value<int>? zIndex,
    Value<int>? colorArgb,
    Value<CardStatus>? status,
    Value<int?>? completedAt,
    Value<bool>? carriedOver,
    Value<String>? originalDayKey,
    Value<int?>? deletedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? eventTime,
    Value<CardTimePrecision?>? eventTimePrecision,
    Value<bool>? eventTimePending,
    Value<String?>? dueTime,
    Value<CardTimePrecision?>? dueTimePrecision,
    Value<bool>? dueTimePending,
    Value<int>? rowid,
  }) {
    return TaskCardsCompanion(
      id: id ?? this.id,
      dayKey: dayKey ?? this.dayKey,
      title: title ?? this.title,
      note: note ?? this.note,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      zIndex: zIndex ?? this.zIndex,
      colorArgb: colorArgb ?? this.colorArgb,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      carriedOver: carriedOver ?? this.carriedOver,
      originalDayKey: originalDayKey ?? this.originalDayKey,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      eventTime: eventTime ?? this.eventTime,
      eventTimePrecision: eventTimePrecision ?? this.eventTimePrecision,
      eventTimePending: eventTimePending ?? this.eventTimePending,
      dueTime: dueTime ?? this.dueTime,
      dueTimePrecision: dueTimePrecision ?? this.dueTimePrecision,
      dueTimePending: dueTimePending ?? this.dueTimePending,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (zIndex.present) {
      map['z_index'] = Variable<int>(zIndex.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TaskCardsTable.$converterstatus.toSql(status.value),
      );
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (carriedOver.present) {
      map['carried_over'] = Variable<bool>(carriedOver.value);
    }
    if (originalDayKey.present) {
      map['original_day_key'] = Variable<String>(originalDayKey.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (eventTime.present) {
      map['event_time'] = Variable<String>(eventTime.value);
    }
    if (eventTimePrecision.present) {
      map['event_time_precision'] = Variable<String>(
        $TaskCardsTable.$convertereventTimePrecisionn.toSql(
          eventTimePrecision.value,
        ),
      );
    }
    if (eventTimePending.present) {
      map['event_time_pending'] = Variable<bool>(eventTimePending.value);
    }
    if (dueTime.present) {
      map['due_time'] = Variable<String>(dueTime.value);
    }
    if (dueTimePrecision.present) {
      map['due_time_precision'] = Variable<String>(
        $TaskCardsTable.$converterdueTimePrecisionn.toSql(
          dueTimePrecision.value,
        ),
      );
    }
    if (dueTimePending.present) {
      map['due_time_pending'] = Variable<bool>(dueTimePending.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskCardsCompanion(')
          ..write('id: $id, ')
          ..write('dayKey: $dayKey, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('zIndex: $zIndex, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('carriedOver: $carriedOver, ')
          ..write('originalDayKey: $originalDayKey, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('eventTime: $eventTime, ')
          ..write('eventTimePrecision: $eventTimePrecision, ')
          ..write('eventTimePending: $eventTimePending, ')
          ..write('dueTime: $dueTime, ')
          ..write('dueTimePrecision: $dueTimePrecision, ')
          ..write('dueTimePending: $dueTimePending, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LinksTable extends Links with TableInfo<$LinksTable, LinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromCardIdMeta = const VerificationMeta(
    'fromCardId',
  );
  @override
  late final GeneratedColumn<String> fromCardId = GeneratedColumn<String>(
    'from_card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_cards (id)',
    ),
  );
  static const VerificationMeta _toCardIdMeta = const VerificationMeta(
    'toCardId',
  );
  @override
  late final GeneratedColumn<String> toCardId = GeneratedColumn<String>(
    'to_card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_cards (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LinkKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LinkKind>($LinksTable.$converterkind);
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fromCardId,
    toCardId,
    kind,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'links';
  @override
  VerificationContext validateIntegrity(
    Insertable<LinkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('from_card_id')) {
      context.handle(
        _fromCardIdMeta,
        fromCardId.isAcceptableOrUnknown(
          data['from_card_id']!,
          _fromCardIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromCardIdMeta);
    }
    if (data.containsKey('to_card_id')) {
      context.handle(
        _toCardIdMeta,
        toCardId.isAcceptableOrUnknown(data['to_card_id']!, _toCardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toCardIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
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
  LinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LinkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fromCardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_card_id'],
      )!,
      toCardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_card_id'],
      )!,
      kind: $LinksTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LinksTable createAlias(String alias) {
    return $LinksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LinkKind, String, String> $converterkind =
      const EnumNameConverter<LinkKind>(LinkKind.values);
}

class LinkRow extends DataClass implements Insertable<LinkRow> {
  final String id;
  final String fromCardId;
  final String toCardId;
  final LinkKind kind;
  final int? deletedAt;
  final int createdAt;
  final int updatedAt;
  const LinkRow({
    required this.id,
    required this.fromCardId,
    required this.toCardId,
    required this.kind,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['from_card_id'] = Variable<String>(fromCardId);
    map['to_card_id'] = Variable<String>(toCardId);
    {
      map['kind'] = Variable<String>($LinksTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LinksCompanion toCompanion(bool nullToAbsent) {
    return LinksCompanion(
      id: Value(id),
      fromCardId: Value(fromCardId),
      toCardId: Value(toCardId),
      kind: Value(kind),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LinkRow(
      id: serializer.fromJson<String>(json['id']),
      fromCardId: serializer.fromJson<String>(json['fromCardId']),
      toCardId: serializer.fromJson<String>(json['toCardId']),
      kind: $LinksTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fromCardId': serializer.toJson<String>(fromCardId),
      'toCardId': serializer.toJson<String>(toCardId),
      'kind': serializer.toJson<String>(
        $LinksTable.$converterkind.toJson(kind),
      ),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LinkRow copyWith({
    String? id,
    String? fromCardId,
    String? toCardId,
    LinkKind? kind,
    Value<int?> deletedAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => LinkRow(
    id: id ?? this.id,
    fromCardId: fromCardId ?? this.fromCardId,
    toCardId: toCardId ?? this.toCardId,
    kind: kind ?? this.kind,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LinkRow copyWithCompanion(LinksCompanion data) {
    return LinkRow(
      id: data.id.present ? data.id.value : this.id,
      fromCardId: data.fromCardId.present
          ? data.fromCardId.value
          : this.fromCardId,
      toCardId: data.toCardId.present ? data.toCardId.value : this.toCardId,
      kind: data.kind.present ? data.kind.value : this.kind,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LinkRow(')
          ..write('id: $id, ')
          ..write('fromCardId: $fromCardId, ')
          ..write('toCardId: $toCardId, ')
          ..write('kind: $kind, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fromCardId,
    toCardId,
    kind,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LinkRow &&
          other.id == this.id &&
          other.fromCardId == this.fromCardId &&
          other.toCardId == this.toCardId &&
          other.kind == this.kind &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LinksCompanion extends UpdateCompanion<LinkRow> {
  final Value<String> id;
  final Value<String> fromCardId;
  final Value<String> toCardId;
  final Value<LinkKind> kind;
  final Value<int?> deletedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LinksCompanion({
    this.id = const Value.absent(),
    this.fromCardId = const Value.absent(),
    this.toCardId = const Value.absent(),
    this.kind = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LinksCompanion.insert({
    required String id,
    required String fromCardId,
    required String toCardId,
    required LinkKind kind,
    this.deletedAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fromCardId = Value(fromCardId),
       toCardId = Value(toCardId),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LinkRow> custom({
    Expression<String>? id,
    Expression<String>? fromCardId,
    Expression<String>? toCardId,
    Expression<String>? kind,
    Expression<int>? deletedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromCardId != null) 'from_card_id': fromCardId,
      if (toCardId != null) 'to_card_id': toCardId,
      if (kind != null) 'kind': kind,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LinksCompanion copyWith({
    Value<String>? id,
    Value<String>? fromCardId,
    Value<String>? toCardId,
    Value<LinkKind>? kind,
    Value<int?>? deletedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return LinksCompanion(
      id: id ?? this.id,
      fromCardId: fromCardId ?? this.fromCardId,
      toCardId: toCardId ?? this.toCardId,
      kind: kind ?? this.kind,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fromCardId.present) {
      map['from_card_id'] = Variable<String>(fromCardId.value);
    }
    if (toCardId.present) {
      map['to_card_id'] = Variable<String>(toCardId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $LinksTable.$converterkind.toSql(kind.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LinksCompanion(')
          ..write('id: $id, ')
          ..write('fromCardId: $fromCardId, ')
          ..write('toCardId: $toCardId, ')
          ..write('kind: $kind, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CarryOverRecordsTable extends CarryOverRecords
    with TableInfo<$CarryOverRecordsTable, CarryOverRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarryOverRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_cards (id)',
    ),
  );
  static const VerificationMeta _fromDayKeyMeta = const VerificationMeta(
    'fromDayKey',
  );
  @override
  late final GeneratedColumn<String> fromDayKey = GeneratedColumn<String>(
    'from_day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toDayKeyMeta = const VerificationMeta(
    'toDayKey',
  );
  @override
  late final GeneratedColumn<String> toDayKey = GeneratedColumn<String>(
    'to_day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleSnapshotMeta = const VerificationMeta(
    'titleSnapshot',
  );
  @override
  late final GeneratedColumn<String> titleSnapshot = GeneratedColumn<String>(
    'title_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carriedAtMeta = const VerificationMeta(
    'carriedAt',
  );
  @override
  late final GeneratedColumn<int> carriedAt = GeneratedColumn<int>(
    'carried_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    fromDayKey,
    toDayKey,
    x,
    y,
    width,
    height,
    titleSnapshot,
    colorArgb,
    carriedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carry_over_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarryOverRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('from_day_key')) {
      context.handle(
        _fromDayKeyMeta,
        fromDayKey.isAcceptableOrUnknown(
          data['from_day_key']!,
          _fromDayKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromDayKeyMeta);
    }
    if (data.containsKey('to_day_key')) {
      context.handle(
        _toDayKeyMeta,
        toDayKey.isAcceptableOrUnknown(data['to_day_key']!, _toDayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_toDayKeyMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('title_snapshot')) {
      context.handle(
        _titleSnapshotMeta,
        titleSnapshot.isAcceptableOrUnknown(
          data['title_snapshot']!,
          _titleSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_titleSnapshotMeta);
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    } else if (isInserting) {
      context.missing(_colorArgbMeta);
    }
    if (data.containsKey('carried_at')) {
      context.handle(
        _carriedAtMeta,
        carriedAt.isAcceptableOrUnknown(data['carried_at']!, _carriedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_carriedAtMeta);
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
  CarryOverRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarryOverRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      fromDayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_day_key'],
      )!,
      toDayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_day_key'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      titleSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_snapshot'],
      )!,
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      )!,
      carriedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carried_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CarryOverRecordsTable createAlias(String alias) {
    return $CarryOverRecordsTable(attachedDatabase, alias);
  }
}

class CarryOverRecordRow extends DataClass
    implements Insertable<CarryOverRecordRow> {
  final String id;
  final String cardId;
  final String fromDayKey;
  final String toDayKey;
  final double x;
  final double y;
  final double width;
  final double height;
  final String titleSnapshot;
  final int colorArgb;
  final int carriedAt;
  final int createdAt;
  final int updatedAt;
  const CarryOverRecordRow({
    required this.id,
    required this.cardId,
    required this.fromDayKey,
    required this.toDayKey,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.titleSnapshot,
    required this.colorArgb,
    required this.carriedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['card_id'] = Variable<String>(cardId);
    map['from_day_key'] = Variable<String>(fromDayKey);
    map['to_day_key'] = Variable<String>(toDayKey);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    map['title_snapshot'] = Variable<String>(titleSnapshot);
    map['color_argb'] = Variable<int>(colorArgb);
    map['carried_at'] = Variable<int>(carriedAt);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CarryOverRecordsCompanion toCompanion(bool nullToAbsent) {
    return CarryOverRecordsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      fromDayKey: Value(fromDayKey),
      toDayKey: Value(toDayKey),
      x: Value(x),
      y: Value(y),
      width: Value(width),
      height: Value(height),
      titleSnapshot: Value(titleSnapshot),
      colorArgb: Value(colorArgb),
      carriedAt: Value(carriedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CarryOverRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarryOverRecordRow(
      id: serializer.fromJson<String>(json['id']),
      cardId: serializer.fromJson<String>(json['cardId']),
      fromDayKey: serializer.fromJson<String>(json['fromDayKey']),
      toDayKey: serializer.fromJson<String>(json['toDayKey']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      titleSnapshot: serializer.fromJson<String>(json['titleSnapshot']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      carriedAt: serializer.fromJson<int>(json['carriedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cardId': serializer.toJson<String>(cardId),
      'fromDayKey': serializer.toJson<String>(fromDayKey),
      'toDayKey': serializer.toJson<String>(toDayKey),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'titleSnapshot': serializer.toJson<String>(titleSnapshot),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'carriedAt': serializer.toJson<int>(carriedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CarryOverRecordRow copyWith({
    String? id,
    String? cardId,
    String? fromDayKey,
    String? toDayKey,
    double? x,
    double? y,
    double? width,
    double? height,
    String? titleSnapshot,
    int? colorArgb,
    int? carriedAt,
    int? createdAt,
    int? updatedAt,
  }) => CarryOverRecordRow(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    fromDayKey: fromDayKey ?? this.fromDayKey,
    toDayKey: toDayKey ?? this.toDayKey,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    titleSnapshot: titleSnapshot ?? this.titleSnapshot,
    colorArgb: colorArgb ?? this.colorArgb,
    carriedAt: carriedAt ?? this.carriedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CarryOverRecordRow copyWithCompanion(CarryOverRecordsCompanion data) {
    return CarryOverRecordRow(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      fromDayKey: data.fromDayKey.present
          ? data.fromDayKey.value
          : this.fromDayKey,
      toDayKey: data.toDayKey.present ? data.toDayKey.value : this.toDayKey,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      titleSnapshot: data.titleSnapshot.present
          ? data.titleSnapshot.value
          : this.titleSnapshot,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      carriedAt: data.carriedAt.present ? data.carriedAt.value : this.carriedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarryOverRecordRow(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('fromDayKey: $fromDayKey, ')
          ..write('toDayKey: $toDayKey, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('titleSnapshot: $titleSnapshot, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('carriedAt: $carriedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    fromDayKey,
    toDayKey,
    x,
    y,
    width,
    height,
    titleSnapshot,
    colorArgb,
    carriedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarryOverRecordRow &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.fromDayKey == this.fromDayKey &&
          other.toDayKey == this.toDayKey &&
          other.x == this.x &&
          other.y == this.y &&
          other.width == this.width &&
          other.height == this.height &&
          other.titleSnapshot == this.titleSnapshot &&
          other.colorArgb == this.colorArgb &&
          other.carriedAt == this.carriedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CarryOverRecordsCompanion extends UpdateCompanion<CarryOverRecordRow> {
  final Value<String> id;
  final Value<String> cardId;
  final Value<String> fromDayKey;
  final Value<String> toDayKey;
  final Value<double> x;
  final Value<double> y;
  final Value<double> width;
  final Value<double> height;
  final Value<String> titleSnapshot;
  final Value<int> colorArgb;
  final Value<int> carriedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CarryOverRecordsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.fromDayKey = const Value.absent(),
    this.toDayKey = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.titleSnapshot = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.carriedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CarryOverRecordsCompanion.insert({
    required String id,
    required String cardId,
    required String fromDayKey,
    required String toDayKey,
    required double x,
    required double y,
    required double width,
    required double height,
    required String titleSnapshot,
    required int colorArgb,
    required int carriedAt,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cardId = Value(cardId),
       fromDayKey = Value(fromDayKey),
       toDayKey = Value(toDayKey),
       x = Value(x),
       y = Value(y),
       width = Value(width),
       height = Value(height),
       titleSnapshot = Value(titleSnapshot),
       colorArgb = Value(colorArgb),
       carriedAt = Value(carriedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CarryOverRecordRow> custom({
    Expression<String>? id,
    Expression<String>? cardId,
    Expression<String>? fromDayKey,
    Expression<String>? toDayKey,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? width,
    Expression<double>? height,
    Expression<String>? titleSnapshot,
    Expression<int>? colorArgb,
    Expression<int>? carriedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (fromDayKey != null) 'from_day_key': fromDayKey,
      if (toDayKey != null) 'to_day_key': toDayKey,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (titleSnapshot != null) 'title_snapshot': titleSnapshot,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (carriedAt != null) 'carried_at': carriedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CarryOverRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? cardId,
    Value<String>? fromDayKey,
    Value<String>? toDayKey,
    Value<double>? x,
    Value<double>? y,
    Value<double>? width,
    Value<double>? height,
    Value<String>? titleSnapshot,
    Value<int>? colorArgb,
    Value<int>? carriedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CarryOverRecordsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      fromDayKey: fromDayKey ?? this.fromDayKey,
      toDayKey: toDayKey ?? this.toDayKey,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      titleSnapshot: titleSnapshot ?? this.titleSnapshot,
      colorArgb: colorArgb ?? this.colorArgb,
      carriedAt: carriedAt ?? this.carriedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (fromDayKey.present) {
      map['from_day_key'] = Variable<String>(fromDayKey.value);
    }
    if (toDayKey.present) {
      map['to_day_key'] = Variable<String>(toDayKey.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (titleSnapshot.present) {
      map['title_snapshot'] = Variable<String>(titleSnapshot.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (carriedAt.present) {
      map['carried_at'] = Variable<int>(carriedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarryOverRecordsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('fromDayKey: $fromDayKey, ')
          ..write('toDayKey: $toDayKey, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('titleSnapshot: $titleSnapshot, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('carriedAt: $carriedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetaTable extends AppMeta
    with TableInfo<$AppMetaTable, AppMetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetaTable createAlias(String alias) {
    return $AppMetaTable(attachedDatabase, alias);
  }
}

class AppMetaEntry extends DataClass implements Insertable<AppMetaEntry> {
  final String key;
  final String value;
  const AppMetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(key: Value(key), value: Value(value));
  }

  factory AppMetaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetaEntry copyWith({String? key, String? value}) =>
      AppMetaEntry(key: key ?? this.key, value: value ?? this.value);
  AppMetaEntry copyWithCompanion(AppMetaCompanion data) {
    return AppMetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetaEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<AppMetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppMetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MailExportFilesTable extends MailExportFiles
    with TableInfo<$MailExportFilesTable, MailExportFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MailExportFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileModifiedAtMeta = const VerificationMeta(
    'fileModifiedAt',
  );
  @override
  late final GeneratedColumn<int> fileModifiedAt = GeneratedColumn<int>(
    'file_modified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MailExportFileStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MailExportFileStatus>($MailExportFilesTable.$converterstatus);
  static const VerificationMeta _errorTypeMeta = const VerificationMeta(
    'errorType',
  );
  @override
  late final GeneratedColumn<String> errorType = GeneratedColumn<String>(
    'error_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mailboxMeta = const VerificationMeta(
    'mailbox',
  );
  @override
  late final GeneratedColumn<String> mailbox = GeneratedColumn<String>(
    'mailbox',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exportedAtMeta = const VerificationMeta(
    'exportedAt',
  );
  @override
  late final GeneratedColumn<int> exportedAt = GeneratedColumn<int>(
    'exported_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _earliestReceivedAtMeta =
      const VerificationMeta('earliestReceivedAt');
  @override
  late final GeneratedColumn<int> earliestReceivedAt = GeneratedColumn<int>(
    'earliest_received_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latestReceivedAtMeta = const VerificationMeta(
    'latestReceivedAt',
  );
  @override
  late final GeneratedColumn<int> latestReceivedAt = GeneratedColumn<int>(
    'latest_received_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mailCountMeta = const VerificationMeta(
    'mailCount',
  );
  @override
  late final GeneratedColumn<int> mailCount = GeneratedColumn<int>(
    'mail_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newMailCountMeta = const VerificationMeta(
    'newMailCount',
  );
  @override
  late final GeneratedColumn<int> newMailCount = GeneratedColumn<int>(
    'new_mail_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skippedCountMeta = const VerificationMeta(
    'skippedCount',
  );
  @override
  late final GeneratedColumn<int> skippedCount = GeneratedColumn<int>(
    'skipped_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<int> firstSeenAt = GeneratedColumn<int>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<int> importedAt = GeneratedColumn<int>(
    'imported_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unchangedSinceMeta = const VerificationMeta(
    'unchangedSince',
  );
  @override
  late final GeneratedColumn<int> unchangedSince = GeneratedColumn<int>(
    'unchanged_since',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileName,
    fileSize,
    fileModifiedAt,
    contentHash,
    status,
    errorType,
    mailbox,
    exportedAt,
    earliestReceivedAt,
    latestReceivedAt,
    mailCount,
    newMailCount,
    skippedCount,
    firstSeenAt,
    importedAt,
    unchangedSince,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mail_export_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<MailExportFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('file_modified_at')) {
      context.handle(
        _fileModifiedAtMeta,
        fileModifiedAt.isAcceptableOrUnknown(
          data['file_modified_at']!,
          _fileModifiedAtMeta,
        ),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('error_type')) {
      context.handle(
        _errorTypeMeta,
        errorType.isAcceptableOrUnknown(data['error_type']!, _errorTypeMeta),
      );
    }
    if (data.containsKey('mailbox')) {
      context.handle(
        _mailboxMeta,
        mailbox.isAcceptableOrUnknown(data['mailbox']!, _mailboxMeta),
      );
    }
    if (data.containsKey('exported_at')) {
      context.handle(
        _exportedAtMeta,
        exportedAt.isAcceptableOrUnknown(data['exported_at']!, _exportedAtMeta),
      );
    }
    if (data.containsKey('earliest_received_at')) {
      context.handle(
        _earliestReceivedAtMeta,
        earliestReceivedAt.isAcceptableOrUnknown(
          data['earliest_received_at']!,
          _earliestReceivedAtMeta,
        ),
      );
    }
    if (data.containsKey('latest_received_at')) {
      context.handle(
        _latestReceivedAtMeta,
        latestReceivedAt.isAcceptableOrUnknown(
          data['latest_received_at']!,
          _latestReceivedAtMeta,
        ),
      );
    }
    if (data.containsKey('mail_count')) {
      context.handle(
        _mailCountMeta,
        mailCount.isAcceptableOrUnknown(data['mail_count']!, _mailCountMeta),
      );
    }
    if (data.containsKey('new_mail_count')) {
      context.handle(
        _newMailCountMeta,
        newMailCount.isAcceptableOrUnknown(
          data['new_mail_count']!,
          _newMailCountMeta,
        ),
      );
    }
    if (data.containsKey('skipped_count')) {
      context.handle(
        _skippedCountMeta,
        skippedCount.isAcceptableOrUnknown(
          data['skipped_count']!,
          _skippedCountMeta,
        ),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    }
    if (data.containsKey('unchanged_since')) {
      context.handle(
        _unchangedSinceMeta,
        unchangedSince.isAcceptableOrUnknown(
          data['unchanged_since']!,
          _unchangedSinceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MailExportFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MailExportFileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      fileModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_modified_at'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      status: $MailExportFilesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      errorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_type'],
      ),
      mailbox: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mailbox'],
      ),
      exportedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exported_at'],
      ),
      earliestReceivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}earliest_received_at'],
      ),
      latestReceivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_received_at'],
      ),
      mailCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mail_count'],
      ),
      newMailCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}new_mail_count'],
      ),
      skippedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skipped_count'],
      ),
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen_at'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at'],
      ),
      unchangedSince: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unchanged_since'],
      ),
    );
  }

  @override
  $MailExportFilesTable createAlias(String alias) {
    return $MailExportFilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MailExportFileStatus, String, String>
  $converterstatus = const EnumNameConverter<MailExportFileStatus>(
    MailExportFileStatus.values,
  );
}

class MailExportFileRow extends DataClass
    implements Insertable<MailExportFileRow> {
  final String id;
  final String fileName;
  final int? fileSize;
  final int? fileModifiedAt;

  /// 还没读过（`seen`）时为空（schemaVersion 4 起可为空，并且不再唯一：
  /// OneDrive 生成的副本和原文件内容一样）。
  final String? contentHash;
  final MailExportFileStatus status;
  final String? errorType;
  final String? mailbox;
  final int? exportedAt;
  final int? earliestReceivedAt;
  final int? latestReceivedAt;
  final int? mailCount;
  final int? newMailCount;

  /// 缺少邮件键、被跳过的邮件数。
  final int? skippedCount;
  final int firstSeenAt;
  final int? importedAt;

  /// 扫描时大小和修改时间从什么时候起没再变过。手动导入的文件为空。
  final int? unchangedSince;
  const MailExportFileRow({
    required this.id,
    required this.fileName,
    this.fileSize,
    this.fileModifiedAt,
    this.contentHash,
    required this.status,
    this.errorType,
    this.mailbox,
    this.exportedAt,
    this.earliestReceivedAt,
    this.latestReceivedAt,
    this.mailCount,
    this.newMailCount,
    this.skippedCount,
    required this.firstSeenAt,
    this.importedAt,
    this.unchangedSince,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || fileModifiedAt != null) {
      map['file_modified_at'] = Variable<int>(fileModifiedAt);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    {
      map['status'] = Variable<String>(
        $MailExportFilesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || errorType != null) {
      map['error_type'] = Variable<String>(errorType);
    }
    if (!nullToAbsent || mailbox != null) {
      map['mailbox'] = Variable<String>(mailbox);
    }
    if (!nullToAbsent || exportedAt != null) {
      map['exported_at'] = Variable<int>(exportedAt);
    }
    if (!nullToAbsent || earliestReceivedAt != null) {
      map['earliest_received_at'] = Variable<int>(earliestReceivedAt);
    }
    if (!nullToAbsent || latestReceivedAt != null) {
      map['latest_received_at'] = Variable<int>(latestReceivedAt);
    }
    if (!nullToAbsent || mailCount != null) {
      map['mail_count'] = Variable<int>(mailCount);
    }
    if (!nullToAbsent || newMailCount != null) {
      map['new_mail_count'] = Variable<int>(newMailCount);
    }
    if (!nullToAbsent || skippedCount != null) {
      map['skipped_count'] = Variable<int>(skippedCount);
    }
    map['first_seen_at'] = Variable<int>(firstSeenAt);
    if (!nullToAbsent || importedAt != null) {
      map['imported_at'] = Variable<int>(importedAt);
    }
    if (!nullToAbsent || unchangedSince != null) {
      map['unchanged_since'] = Variable<int>(unchangedSince);
    }
    return map;
  }

  MailExportFilesCompanion toCompanion(bool nullToAbsent) {
    return MailExportFilesCompanion(
      id: Value(id),
      fileName: Value(fileName),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      fileModifiedAt: fileModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fileModifiedAt),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      status: Value(status),
      errorType: errorType == null && nullToAbsent
          ? const Value.absent()
          : Value(errorType),
      mailbox: mailbox == null && nullToAbsent
          ? const Value.absent()
          : Value(mailbox),
      exportedAt: exportedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(exportedAt),
      earliestReceivedAt: earliestReceivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(earliestReceivedAt),
      latestReceivedAt: latestReceivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(latestReceivedAt),
      mailCount: mailCount == null && nullToAbsent
          ? const Value.absent()
          : Value(mailCount),
      newMailCount: newMailCount == null && nullToAbsent
          ? const Value.absent()
          : Value(newMailCount),
      skippedCount: skippedCount == null && nullToAbsent
          ? const Value.absent()
          : Value(skippedCount),
      firstSeenAt: Value(firstSeenAt),
      importedAt: importedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(importedAt),
      unchangedSince: unchangedSince == null && nullToAbsent
          ? const Value.absent()
          : Value(unchangedSince),
    );
  }

  factory MailExportFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MailExportFileRow(
      id: serializer.fromJson<String>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      fileModifiedAt: serializer.fromJson<int?>(json['fileModifiedAt']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      status: $MailExportFilesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      errorType: serializer.fromJson<String?>(json['errorType']),
      mailbox: serializer.fromJson<String?>(json['mailbox']),
      exportedAt: serializer.fromJson<int?>(json['exportedAt']),
      earliestReceivedAt: serializer.fromJson<int?>(json['earliestReceivedAt']),
      latestReceivedAt: serializer.fromJson<int?>(json['latestReceivedAt']),
      mailCount: serializer.fromJson<int?>(json['mailCount']),
      newMailCount: serializer.fromJson<int?>(json['newMailCount']),
      skippedCount: serializer.fromJson<int?>(json['skippedCount']),
      firstSeenAt: serializer.fromJson<int>(json['firstSeenAt']),
      importedAt: serializer.fromJson<int?>(json['importedAt']),
      unchangedSince: serializer.fromJson<int?>(json['unchangedSince']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fileName': serializer.toJson<String>(fileName),
      'fileSize': serializer.toJson<int?>(fileSize),
      'fileModifiedAt': serializer.toJson<int?>(fileModifiedAt),
      'contentHash': serializer.toJson<String?>(contentHash),
      'status': serializer.toJson<String>(
        $MailExportFilesTable.$converterstatus.toJson(status),
      ),
      'errorType': serializer.toJson<String?>(errorType),
      'mailbox': serializer.toJson<String?>(mailbox),
      'exportedAt': serializer.toJson<int?>(exportedAt),
      'earliestReceivedAt': serializer.toJson<int?>(earliestReceivedAt),
      'latestReceivedAt': serializer.toJson<int?>(latestReceivedAt),
      'mailCount': serializer.toJson<int?>(mailCount),
      'newMailCount': serializer.toJson<int?>(newMailCount),
      'skippedCount': serializer.toJson<int?>(skippedCount),
      'firstSeenAt': serializer.toJson<int>(firstSeenAt),
      'importedAt': serializer.toJson<int?>(importedAt),
      'unchangedSince': serializer.toJson<int?>(unchangedSince),
    };
  }

  MailExportFileRow copyWith({
    String? id,
    String? fileName,
    Value<int?> fileSize = const Value.absent(),
    Value<int?> fileModifiedAt = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
    MailExportFileStatus? status,
    Value<String?> errorType = const Value.absent(),
    Value<String?> mailbox = const Value.absent(),
    Value<int?> exportedAt = const Value.absent(),
    Value<int?> earliestReceivedAt = const Value.absent(),
    Value<int?> latestReceivedAt = const Value.absent(),
    Value<int?> mailCount = const Value.absent(),
    Value<int?> newMailCount = const Value.absent(),
    Value<int?> skippedCount = const Value.absent(),
    int? firstSeenAt,
    Value<int?> importedAt = const Value.absent(),
    Value<int?> unchangedSince = const Value.absent(),
  }) => MailExportFileRow(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    fileModifiedAt: fileModifiedAt.present
        ? fileModifiedAt.value
        : this.fileModifiedAt,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    status: status ?? this.status,
    errorType: errorType.present ? errorType.value : this.errorType,
    mailbox: mailbox.present ? mailbox.value : this.mailbox,
    exportedAt: exportedAt.present ? exportedAt.value : this.exportedAt,
    earliestReceivedAt: earliestReceivedAt.present
        ? earliestReceivedAt.value
        : this.earliestReceivedAt,
    latestReceivedAt: latestReceivedAt.present
        ? latestReceivedAt.value
        : this.latestReceivedAt,
    mailCount: mailCount.present ? mailCount.value : this.mailCount,
    newMailCount: newMailCount.present ? newMailCount.value : this.newMailCount,
    skippedCount: skippedCount.present ? skippedCount.value : this.skippedCount,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    importedAt: importedAt.present ? importedAt.value : this.importedAt,
    unchangedSince: unchangedSince.present
        ? unchangedSince.value
        : this.unchangedSince,
  );
  MailExportFileRow copyWithCompanion(MailExportFilesCompanion data) {
    return MailExportFileRow(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      fileModifiedAt: data.fileModifiedAt.present
          ? data.fileModifiedAt.value
          : this.fileModifiedAt,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      status: data.status.present ? data.status.value : this.status,
      errorType: data.errorType.present ? data.errorType.value : this.errorType,
      mailbox: data.mailbox.present ? data.mailbox.value : this.mailbox,
      exportedAt: data.exportedAt.present
          ? data.exportedAt.value
          : this.exportedAt,
      earliestReceivedAt: data.earliestReceivedAt.present
          ? data.earliestReceivedAt.value
          : this.earliestReceivedAt,
      latestReceivedAt: data.latestReceivedAt.present
          ? data.latestReceivedAt.value
          : this.latestReceivedAt,
      mailCount: data.mailCount.present ? data.mailCount.value : this.mailCount,
      newMailCount: data.newMailCount.present
          ? data.newMailCount.value
          : this.newMailCount,
      skippedCount: data.skippedCount.present
          ? data.skippedCount.value
          : this.skippedCount,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      unchangedSince: data.unchangedSince.present
          ? data.unchangedSince.value
          : this.unchangedSince,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MailExportFileRow(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('fileModifiedAt: $fileModifiedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('status: $status, ')
          ..write('errorType: $errorType, ')
          ..write('mailbox: $mailbox, ')
          ..write('exportedAt: $exportedAt, ')
          ..write('earliestReceivedAt: $earliestReceivedAt, ')
          ..write('latestReceivedAt: $latestReceivedAt, ')
          ..write('mailCount: $mailCount, ')
          ..write('newMailCount: $newMailCount, ')
          ..write('skippedCount: $skippedCount, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('importedAt: $importedAt, ')
          ..write('unchangedSince: $unchangedSince')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fileName,
    fileSize,
    fileModifiedAt,
    contentHash,
    status,
    errorType,
    mailbox,
    exportedAt,
    earliestReceivedAt,
    latestReceivedAt,
    mailCount,
    newMailCount,
    skippedCount,
    firstSeenAt,
    importedAt,
    unchangedSince,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MailExportFileRow &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.fileSize == this.fileSize &&
          other.fileModifiedAt == this.fileModifiedAt &&
          other.contentHash == this.contentHash &&
          other.status == this.status &&
          other.errorType == this.errorType &&
          other.mailbox == this.mailbox &&
          other.exportedAt == this.exportedAt &&
          other.earliestReceivedAt == this.earliestReceivedAt &&
          other.latestReceivedAt == this.latestReceivedAt &&
          other.mailCount == this.mailCount &&
          other.newMailCount == this.newMailCount &&
          other.skippedCount == this.skippedCount &&
          other.firstSeenAt == this.firstSeenAt &&
          other.importedAt == this.importedAt &&
          other.unchangedSince == this.unchangedSince);
}

class MailExportFilesCompanion extends UpdateCompanion<MailExportFileRow> {
  final Value<String> id;
  final Value<String> fileName;
  final Value<int?> fileSize;
  final Value<int?> fileModifiedAt;
  final Value<String?> contentHash;
  final Value<MailExportFileStatus> status;
  final Value<String?> errorType;
  final Value<String?> mailbox;
  final Value<int?> exportedAt;
  final Value<int?> earliestReceivedAt;
  final Value<int?> latestReceivedAt;
  final Value<int?> mailCount;
  final Value<int?> newMailCount;
  final Value<int?> skippedCount;
  final Value<int> firstSeenAt;
  final Value<int?> importedAt;
  final Value<int?> unchangedSince;
  final Value<int> rowid;
  const MailExportFilesCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.fileModifiedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.status = const Value.absent(),
    this.errorType = const Value.absent(),
    this.mailbox = const Value.absent(),
    this.exportedAt = const Value.absent(),
    this.earliestReceivedAt = const Value.absent(),
    this.latestReceivedAt = const Value.absent(),
    this.mailCount = const Value.absent(),
    this.newMailCount = const Value.absent(),
    this.skippedCount = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.unchangedSince = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MailExportFilesCompanion.insert({
    required String id,
    required String fileName,
    this.fileSize = const Value.absent(),
    this.fileModifiedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    required MailExportFileStatus status,
    this.errorType = const Value.absent(),
    this.mailbox = const Value.absent(),
    this.exportedAt = const Value.absent(),
    this.earliestReceivedAt = const Value.absent(),
    this.latestReceivedAt = const Value.absent(),
    this.mailCount = const Value.absent(),
    this.newMailCount = const Value.absent(),
    this.skippedCount = const Value.absent(),
    required int firstSeenAt,
    this.importedAt = const Value.absent(),
    this.unchangedSince = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fileName = Value(fileName),
       status = Value(status),
       firstSeenAt = Value(firstSeenAt);
  static Insertable<MailExportFileRow> custom({
    Expression<String>? id,
    Expression<String>? fileName,
    Expression<int>? fileSize,
    Expression<int>? fileModifiedAt,
    Expression<String>? contentHash,
    Expression<String>? status,
    Expression<String>? errorType,
    Expression<String>? mailbox,
    Expression<int>? exportedAt,
    Expression<int>? earliestReceivedAt,
    Expression<int>? latestReceivedAt,
    Expression<int>? mailCount,
    Expression<int>? newMailCount,
    Expression<int>? skippedCount,
    Expression<int>? firstSeenAt,
    Expression<int>? importedAt,
    Expression<int>? unchangedSince,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (fileModifiedAt != null) 'file_modified_at': fileModifiedAt,
      if (contentHash != null) 'content_hash': contentHash,
      if (status != null) 'status': status,
      if (errorType != null) 'error_type': errorType,
      if (mailbox != null) 'mailbox': mailbox,
      if (exportedAt != null) 'exported_at': exportedAt,
      if (earliestReceivedAt != null)
        'earliest_received_at': earliestReceivedAt,
      if (latestReceivedAt != null) 'latest_received_at': latestReceivedAt,
      if (mailCount != null) 'mail_count': mailCount,
      if (newMailCount != null) 'new_mail_count': newMailCount,
      if (skippedCount != null) 'skipped_count': skippedCount,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (importedAt != null) 'imported_at': importedAt,
      if (unchangedSince != null) 'unchanged_since': unchangedSince,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MailExportFilesCompanion copyWith({
    Value<String>? id,
    Value<String>? fileName,
    Value<int?>? fileSize,
    Value<int?>? fileModifiedAt,
    Value<String?>? contentHash,
    Value<MailExportFileStatus>? status,
    Value<String?>? errorType,
    Value<String?>? mailbox,
    Value<int?>? exportedAt,
    Value<int?>? earliestReceivedAt,
    Value<int?>? latestReceivedAt,
    Value<int?>? mailCount,
    Value<int?>? newMailCount,
    Value<int?>? skippedCount,
    Value<int>? firstSeenAt,
    Value<int?>? importedAt,
    Value<int?>? unchangedSince,
    Value<int>? rowid,
  }) {
    return MailExportFilesCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileModifiedAt: fileModifiedAt ?? this.fileModifiedAt,
      contentHash: contentHash ?? this.contentHash,
      status: status ?? this.status,
      errorType: errorType ?? this.errorType,
      mailbox: mailbox ?? this.mailbox,
      exportedAt: exportedAt ?? this.exportedAt,
      earliestReceivedAt: earliestReceivedAt ?? this.earliestReceivedAt,
      latestReceivedAt: latestReceivedAt ?? this.latestReceivedAt,
      mailCount: mailCount ?? this.mailCount,
      newMailCount: newMailCount ?? this.newMailCount,
      skippedCount: skippedCount ?? this.skippedCount,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      importedAt: importedAt ?? this.importedAt,
      unchangedSince: unchangedSince ?? this.unchangedSince,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (fileModifiedAt.present) {
      map['file_modified_at'] = Variable<int>(fileModifiedAt.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MailExportFilesTable.$converterstatus.toSql(status.value),
      );
    }
    if (errorType.present) {
      map['error_type'] = Variable<String>(errorType.value);
    }
    if (mailbox.present) {
      map['mailbox'] = Variable<String>(mailbox.value);
    }
    if (exportedAt.present) {
      map['exported_at'] = Variable<int>(exportedAt.value);
    }
    if (earliestReceivedAt.present) {
      map['earliest_received_at'] = Variable<int>(earliestReceivedAt.value);
    }
    if (latestReceivedAt.present) {
      map['latest_received_at'] = Variable<int>(latestReceivedAt.value);
    }
    if (mailCount.present) {
      map['mail_count'] = Variable<int>(mailCount.value);
    }
    if (newMailCount.present) {
      map['new_mail_count'] = Variable<int>(newMailCount.value);
    }
    if (skippedCount.present) {
      map['skipped_count'] = Variable<int>(skippedCount.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<int>(firstSeenAt.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<int>(importedAt.value);
    }
    if (unchangedSince.present) {
      map['unchanged_since'] = Variable<int>(unchangedSince.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MailExportFilesCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('fileModifiedAt: $fileModifiedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('status: $status, ')
          ..write('errorType: $errorType, ')
          ..write('mailbox: $mailbox, ')
          ..write('exportedAt: $exportedAt, ')
          ..write('earliestReceivedAt: $earliestReceivedAt, ')
          ..write('latestReceivedAt: $latestReceivedAt, ')
          ..write('mailCount: $mailCount, ')
          ..write('newMailCount: $newMailCount, ')
          ..write('skippedCount: $skippedCount, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('importedAt: $importedAt, ')
          ..write('unchangedSince: $unchangedSince, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MailsTable extends Mails with TableInfo<$MailsTable, MailRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mailboxMeta = const VerificationMeta(
    'mailbox',
  );
  @override
  late final GeneratedColumn<String> mailbox = GeneratedColumn<String>(
    'mailbox',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mailKeyMeta = const VerificationMeta(
    'mailKey',
  );
  @override
  late final GeneratedColumn<String> mailKey = GeneratedColumn<String>(
    'mail_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MailKeyKind, String> mailKeyKind =
      GeneratedColumn<String>(
        'mail_key_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MailKeyKind>($MailsTable.$convertermailKeyKind);
  static const VerificationMeta _outlookIdMeta = const VerificationMeta(
    'outlookId',
  );
  @override
  late final GeneratedColumn<String> outlookId = GeneratedColumn<String>(
    'outlook_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderNameMeta = const VerificationMeta(
    'senderName',
  );
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
    'sender_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderAddressMeta = const VerificationMeta(
    'senderAddress',
  );
  @override
  late final GeneratedColumn<String> senderAddress = GeneratedColumn<String>(
    'sender_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<int> receivedAt = GeneratedColumn<int>(
    'received_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<String> importance = GeneratedColumn<String>(
    'importance',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasAttachmentsMeta = const VerificationMeta(
    'hasAttachments',
  );
  @override
  late final GeneratedColumn<bool> hasAttachments = GeneratedColumn<bool>(
    'has_attachments',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_attachments" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasInlineImagesMeta = const VerificationMeta(
    'hasInlineImages',
  );
  @override
  late final GeneratedColumn<bool> hasInlineImages = GeneratedColumn<bool>(
    'has_inline_images',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_inline_images" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bodyTextMeta = const VerificationMeta(
    'bodyText',
  );
  @override
  late final GeneratedColumn<String> bodyText = GeneratedColumn<String>(
    'body_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyPossiblyIncompleteMeta =
      const VerificationMeta('bodyPossiblyIncomplete');
  @override
  late final GeneratedColumn<bool> bodyPossiblyIncomplete =
      GeneratedColumn<bool>(
        'body_possibly_incomplete',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("body_possibly_incomplete" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  @override
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
    'links',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyClearedAtMeta = const VerificationMeta(
    'bodyClearedAt',
  );
  @override
  late final GeneratedColumn<int> bodyClearedAt = GeneratedColumn<int>(
    'body_cleared_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MailAnalysisStatus, String>
  analysisStatus = GeneratedColumn<String>(
    'analysis_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MailAnalysisStatus>($MailsTable.$converteranalysisStatus);
  static const VerificationMeta _analysisFailureTypeMeta =
      const VerificationMeta('analysisFailureType');
  @override
  late final GeneratedColumn<String> analysisFailureType =
      GeneratedColumn<String>(
        'analysis_failure_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisFailureCountMeta =
      const VerificationMeta('analysisFailureCount');
  @override
  late final GeneratedColumn<int> analysisFailureCount = GeneratedColumn<int>(
    'analysis_failure_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<int> nextRetryAt = GeneratedColumn<int>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryReasonMeta = const VerificationMeta(
    'categoryReason',
  );
  @override
  late final GeneratedColumn<String> categoryReason = GeneratedColumn<String>(
    'category_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _markedUsefulMeta = const VerificationMeta(
    'markedUseful',
  );
  @override
  late final GeneratedColumn<bool> markedUseful = GeneratedColumn<bool>(
    'marked_useful',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("marked_useful" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceFileIdMeta = const VerificationMeta(
    'sourceFileId',
  );
  @override
  late final GeneratedColumn<String> sourceFileId = GeneratedColumn<String>(
    'source_file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mail_export_files (id)',
    ),
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<int> importedAt = GeneratedColumn<int>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _analyzedAtMeta = const VerificationMeta(
    'analyzedAt',
  );
  @override
  late final GeneratedColumn<int> analyzedAt = GeneratedColumn<int>(
    'analyzed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mailbox,
    mailKey,
    mailKeyKind,
    outlookId,
    conversationId,
    subject,
    senderName,
    senderAddress,
    receivedAt,
    importance,
    hasAttachments,
    hasInlineImages,
    bodyText,
    bodyPossiblyIncomplete,
    links,
    bodyClearedAt,
    analysisStatus,
    analysisFailureType,
    analysisFailureCount,
    nextRetryAt,
    category,
    categoryReason,
    markedUseful,
    sourceFileId,
    importedAt,
    analyzedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mails';
  @override
  VerificationContext validateIntegrity(
    Insertable<MailRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mailbox')) {
      context.handle(
        _mailboxMeta,
        mailbox.isAcceptableOrUnknown(data['mailbox']!, _mailboxMeta),
      );
    } else if (isInserting) {
      context.missing(_mailboxMeta);
    }
    if (data.containsKey('mail_key')) {
      context.handle(
        _mailKeyMeta,
        mailKey.isAcceptableOrUnknown(data['mail_key']!, _mailKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_mailKeyMeta);
    }
    if (data.containsKey('outlook_id')) {
      context.handle(
        _outlookIdMeta,
        outlookId.isAcceptableOrUnknown(data['outlook_id']!, _outlookIdMeta),
      );
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('sender_name')) {
      context.handle(
        _senderNameMeta,
        senderName.isAcceptableOrUnknown(data['sender_name']!, _senderNameMeta),
      );
    }
    if (data.containsKey('sender_address')) {
      context.handle(
        _senderAddressMeta,
        senderAddress.isAcceptableOrUnknown(
          data['sender_address']!,
          _senderAddressMeta,
        ),
      );
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    if (data.containsKey('has_attachments')) {
      context.handle(
        _hasAttachmentsMeta,
        hasAttachments.isAcceptableOrUnknown(
          data['has_attachments']!,
          _hasAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('has_inline_images')) {
      context.handle(
        _hasInlineImagesMeta,
        hasInlineImages.isAcceptableOrUnknown(
          data['has_inline_images']!,
          _hasInlineImagesMeta,
        ),
      );
    }
    if (data.containsKey('body_text')) {
      context.handle(
        _bodyTextMeta,
        bodyText.isAcceptableOrUnknown(data['body_text']!, _bodyTextMeta),
      );
    }
    if (data.containsKey('body_possibly_incomplete')) {
      context.handle(
        _bodyPossiblyIncompleteMeta,
        bodyPossiblyIncomplete.isAcceptableOrUnknown(
          data['body_possibly_incomplete']!,
          _bodyPossiblyIncompleteMeta,
        ),
      );
    }
    if (data.containsKey('links')) {
      context.handle(
        _linksMeta,
        links.isAcceptableOrUnknown(data['links']!, _linksMeta),
      );
    }
    if (data.containsKey('body_cleared_at')) {
      context.handle(
        _bodyClearedAtMeta,
        bodyClearedAt.isAcceptableOrUnknown(
          data['body_cleared_at']!,
          _bodyClearedAtMeta,
        ),
      );
    }
    if (data.containsKey('analysis_failure_type')) {
      context.handle(
        _analysisFailureTypeMeta,
        analysisFailureType.isAcceptableOrUnknown(
          data['analysis_failure_type']!,
          _analysisFailureTypeMeta,
        ),
      );
    }
    if (data.containsKey('analysis_failure_count')) {
      context.handle(
        _analysisFailureCountMeta,
        analysisFailureCount.isAcceptableOrUnknown(
          data['analysis_failure_count']!,
          _analysisFailureCountMeta,
        ),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('category_reason')) {
      context.handle(
        _categoryReasonMeta,
        categoryReason.isAcceptableOrUnknown(
          data['category_reason']!,
          _categoryReasonMeta,
        ),
      );
    }
    if (data.containsKey('marked_useful')) {
      context.handle(
        _markedUsefulMeta,
        markedUseful.isAcceptableOrUnknown(
          data['marked_useful']!,
          _markedUsefulMeta,
        ),
      );
    }
    if (data.containsKey('source_file_id')) {
      context.handle(
        _sourceFileIdMeta,
        sourceFileId.isAcceptableOrUnknown(
          data['source_file_id']!,
          _sourceFileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceFileIdMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('analyzed_at')) {
      context.handle(
        _analyzedAtMeta,
        analyzedAt.isAcceptableOrUnknown(data['analyzed_at']!, _analyzedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {mailbox, mailKey},
  ];
  @override
  MailRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MailRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mailbox: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mailbox'],
      )!,
      mailKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mail_key'],
      )!,
      mailKeyKind: $MailsTable.$convertermailKeyKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mail_key_kind'],
        )!,
      ),
      outlookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outlook_id'],
      ),
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      senderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_name'],
      ),
      senderAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_address'],
      ),
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_at'],
      ),
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}importance'],
      ),
      hasAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_attachments'],
      )!,
      hasInlineImages: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_inline_images'],
      )!,
      bodyText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_text'],
      ),
      bodyPossiblyIncomplete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}body_possibly_incomplete'],
      )!,
      links: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}links'],
      ),
      bodyClearedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}body_cleared_at'],
      ),
      analysisStatus: $MailsTable.$converteranalysisStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}analysis_status'],
        )!,
      ),
      analysisFailureType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_failure_type'],
      ),
      analysisFailureCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_failure_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_retry_at'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      categoryReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_reason'],
      ),
      markedUseful: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}marked_useful'],
      )!,
      sourceFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_file_id'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at'],
      )!,
      analyzedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analyzed_at'],
      ),
    );
  }

  @override
  $MailsTable createAlias(String alias) {
    return $MailsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MailKeyKind, String, String> $convertermailKeyKind =
      const EnumNameConverter<MailKeyKind>(MailKeyKind.values);
  static JsonTypeConverter2<MailAnalysisStatus, String, String>
  $converteranalysisStatus = const EnumNameConverter<MailAnalysisStatus>(
    MailAnalysisStatus.values,
  );
}

class MailRow extends DataClass implements Insertable<MailRow> {
  final String id;
  final String mailbox;
  final String mailKey;
  final MailKeyKind mailKeyKind;
  final String? outlookId;
  final String? conversationId;
  final String subject;
  final String? senderName;
  final String? senderAddress;
  final int? receivedAt;
  final String? importance;
  final bool hasAttachments;
  final bool hasInlineImages;
  final String? bodyText;
  final bool bodyPossiblyIncomplete;

  /// JSON 数组，分析结果用下标引用。
  final String? links;

  /// 正文到期时间每次扫描时现算，不存（schemaVersion 5 删掉了这一列）。
  final int? bodyClearedAt;
  final MailAnalysisStatus analysisStatus;
  final String? analysisFailureType;
  final int analysisFailureCount;
  final int? nextRetryAt;
  final String? category;
  final String? categoryReason;
  final bool markedUseful;
  final String sourceFileId;
  final int importedAt;
  final int? analyzedAt;
  const MailRow({
    required this.id,
    required this.mailbox,
    required this.mailKey,
    required this.mailKeyKind,
    this.outlookId,
    this.conversationId,
    required this.subject,
    this.senderName,
    this.senderAddress,
    this.receivedAt,
    this.importance,
    required this.hasAttachments,
    required this.hasInlineImages,
    this.bodyText,
    required this.bodyPossiblyIncomplete,
    this.links,
    this.bodyClearedAt,
    required this.analysisStatus,
    this.analysisFailureType,
    required this.analysisFailureCount,
    this.nextRetryAt,
    this.category,
    this.categoryReason,
    required this.markedUseful,
    required this.sourceFileId,
    required this.importedAt,
    this.analyzedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mailbox'] = Variable<String>(mailbox);
    map['mail_key'] = Variable<String>(mailKey);
    {
      map['mail_key_kind'] = Variable<String>(
        $MailsTable.$convertermailKeyKind.toSql(mailKeyKind),
      );
    }
    if (!nullToAbsent || outlookId != null) {
      map['outlook_id'] = Variable<String>(outlookId);
    }
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    map['subject'] = Variable<String>(subject);
    if (!nullToAbsent || senderName != null) {
      map['sender_name'] = Variable<String>(senderName);
    }
    if (!nullToAbsent || senderAddress != null) {
      map['sender_address'] = Variable<String>(senderAddress);
    }
    if (!nullToAbsent || receivedAt != null) {
      map['received_at'] = Variable<int>(receivedAt);
    }
    if (!nullToAbsent || importance != null) {
      map['importance'] = Variable<String>(importance);
    }
    map['has_attachments'] = Variable<bool>(hasAttachments);
    map['has_inline_images'] = Variable<bool>(hasInlineImages);
    if (!nullToAbsent || bodyText != null) {
      map['body_text'] = Variable<String>(bodyText);
    }
    map['body_possibly_incomplete'] = Variable<bool>(bodyPossiblyIncomplete);
    if (!nullToAbsent || links != null) {
      map['links'] = Variable<String>(links);
    }
    if (!nullToAbsent || bodyClearedAt != null) {
      map['body_cleared_at'] = Variable<int>(bodyClearedAt);
    }
    {
      map['analysis_status'] = Variable<String>(
        $MailsTable.$converteranalysisStatus.toSql(analysisStatus),
      );
    }
    if (!nullToAbsent || analysisFailureType != null) {
      map['analysis_failure_type'] = Variable<String>(analysisFailureType);
    }
    map['analysis_failure_count'] = Variable<int>(analysisFailureCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<int>(nextRetryAt);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || categoryReason != null) {
      map['category_reason'] = Variable<String>(categoryReason);
    }
    map['marked_useful'] = Variable<bool>(markedUseful);
    map['source_file_id'] = Variable<String>(sourceFileId);
    map['imported_at'] = Variable<int>(importedAt);
    if (!nullToAbsent || analyzedAt != null) {
      map['analyzed_at'] = Variable<int>(analyzedAt);
    }
    return map;
  }

  MailsCompanion toCompanion(bool nullToAbsent) {
    return MailsCompanion(
      id: Value(id),
      mailbox: Value(mailbox),
      mailKey: Value(mailKey),
      mailKeyKind: Value(mailKeyKind),
      outlookId: outlookId == null && nullToAbsent
          ? const Value.absent()
          : Value(outlookId),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      subject: Value(subject),
      senderName: senderName == null && nullToAbsent
          ? const Value.absent()
          : Value(senderName),
      senderAddress: senderAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(senderAddress),
      receivedAt: receivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedAt),
      importance: importance == null && nullToAbsent
          ? const Value.absent()
          : Value(importance),
      hasAttachments: Value(hasAttachments),
      hasInlineImages: Value(hasInlineImages),
      bodyText: bodyText == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyText),
      bodyPossiblyIncomplete: Value(bodyPossiblyIncomplete),
      links: links == null && nullToAbsent
          ? const Value.absent()
          : Value(links),
      bodyClearedAt: bodyClearedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyClearedAt),
      analysisStatus: Value(analysisStatus),
      analysisFailureType: analysisFailureType == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisFailureType),
      analysisFailureCount: Value(analysisFailureCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      categoryReason: categoryReason == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryReason),
      markedUseful: Value(markedUseful),
      sourceFileId: Value(sourceFileId),
      importedAt: Value(importedAt),
      analyzedAt: analyzedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(analyzedAt),
    );
  }

  factory MailRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MailRow(
      id: serializer.fromJson<String>(json['id']),
      mailbox: serializer.fromJson<String>(json['mailbox']),
      mailKey: serializer.fromJson<String>(json['mailKey']),
      mailKeyKind: $MailsTable.$convertermailKeyKind.fromJson(
        serializer.fromJson<String>(json['mailKeyKind']),
      ),
      outlookId: serializer.fromJson<String?>(json['outlookId']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      subject: serializer.fromJson<String>(json['subject']),
      senderName: serializer.fromJson<String?>(json['senderName']),
      senderAddress: serializer.fromJson<String?>(json['senderAddress']),
      receivedAt: serializer.fromJson<int?>(json['receivedAt']),
      importance: serializer.fromJson<String?>(json['importance']),
      hasAttachments: serializer.fromJson<bool>(json['hasAttachments']),
      hasInlineImages: serializer.fromJson<bool>(json['hasInlineImages']),
      bodyText: serializer.fromJson<String?>(json['bodyText']),
      bodyPossiblyIncomplete: serializer.fromJson<bool>(
        json['bodyPossiblyIncomplete'],
      ),
      links: serializer.fromJson<String?>(json['links']),
      bodyClearedAt: serializer.fromJson<int?>(json['bodyClearedAt']),
      analysisStatus: $MailsTable.$converteranalysisStatus.fromJson(
        serializer.fromJson<String>(json['analysisStatus']),
      ),
      analysisFailureType: serializer.fromJson<String?>(
        json['analysisFailureType'],
      ),
      analysisFailureCount: serializer.fromJson<int>(
        json['analysisFailureCount'],
      ),
      nextRetryAt: serializer.fromJson<int?>(json['nextRetryAt']),
      category: serializer.fromJson<String?>(json['category']),
      categoryReason: serializer.fromJson<String?>(json['categoryReason']),
      markedUseful: serializer.fromJson<bool>(json['markedUseful']),
      sourceFileId: serializer.fromJson<String>(json['sourceFileId']),
      importedAt: serializer.fromJson<int>(json['importedAt']),
      analyzedAt: serializer.fromJson<int?>(json['analyzedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mailbox': serializer.toJson<String>(mailbox),
      'mailKey': serializer.toJson<String>(mailKey),
      'mailKeyKind': serializer.toJson<String>(
        $MailsTable.$convertermailKeyKind.toJson(mailKeyKind),
      ),
      'outlookId': serializer.toJson<String?>(outlookId),
      'conversationId': serializer.toJson<String?>(conversationId),
      'subject': serializer.toJson<String>(subject),
      'senderName': serializer.toJson<String?>(senderName),
      'senderAddress': serializer.toJson<String?>(senderAddress),
      'receivedAt': serializer.toJson<int?>(receivedAt),
      'importance': serializer.toJson<String?>(importance),
      'hasAttachments': serializer.toJson<bool>(hasAttachments),
      'hasInlineImages': serializer.toJson<bool>(hasInlineImages),
      'bodyText': serializer.toJson<String?>(bodyText),
      'bodyPossiblyIncomplete': serializer.toJson<bool>(bodyPossiblyIncomplete),
      'links': serializer.toJson<String?>(links),
      'bodyClearedAt': serializer.toJson<int?>(bodyClearedAt),
      'analysisStatus': serializer.toJson<String>(
        $MailsTable.$converteranalysisStatus.toJson(analysisStatus),
      ),
      'analysisFailureType': serializer.toJson<String?>(analysisFailureType),
      'analysisFailureCount': serializer.toJson<int>(analysisFailureCount),
      'nextRetryAt': serializer.toJson<int?>(nextRetryAt),
      'category': serializer.toJson<String?>(category),
      'categoryReason': serializer.toJson<String?>(categoryReason),
      'markedUseful': serializer.toJson<bool>(markedUseful),
      'sourceFileId': serializer.toJson<String>(sourceFileId),
      'importedAt': serializer.toJson<int>(importedAt),
      'analyzedAt': serializer.toJson<int?>(analyzedAt),
    };
  }

  MailRow copyWith({
    String? id,
    String? mailbox,
    String? mailKey,
    MailKeyKind? mailKeyKind,
    Value<String?> outlookId = const Value.absent(),
    Value<String?> conversationId = const Value.absent(),
    String? subject,
    Value<String?> senderName = const Value.absent(),
    Value<String?> senderAddress = const Value.absent(),
    Value<int?> receivedAt = const Value.absent(),
    Value<String?> importance = const Value.absent(),
    bool? hasAttachments,
    bool? hasInlineImages,
    Value<String?> bodyText = const Value.absent(),
    bool? bodyPossiblyIncomplete,
    Value<String?> links = const Value.absent(),
    Value<int?> bodyClearedAt = const Value.absent(),
    MailAnalysisStatus? analysisStatus,
    Value<String?> analysisFailureType = const Value.absent(),
    int? analysisFailureCount,
    Value<int?> nextRetryAt = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> categoryReason = const Value.absent(),
    bool? markedUseful,
    String? sourceFileId,
    int? importedAt,
    Value<int?> analyzedAt = const Value.absent(),
  }) => MailRow(
    id: id ?? this.id,
    mailbox: mailbox ?? this.mailbox,
    mailKey: mailKey ?? this.mailKey,
    mailKeyKind: mailKeyKind ?? this.mailKeyKind,
    outlookId: outlookId.present ? outlookId.value : this.outlookId,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    subject: subject ?? this.subject,
    senderName: senderName.present ? senderName.value : this.senderName,
    senderAddress: senderAddress.present
        ? senderAddress.value
        : this.senderAddress,
    receivedAt: receivedAt.present ? receivedAt.value : this.receivedAt,
    importance: importance.present ? importance.value : this.importance,
    hasAttachments: hasAttachments ?? this.hasAttachments,
    hasInlineImages: hasInlineImages ?? this.hasInlineImages,
    bodyText: bodyText.present ? bodyText.value : this.bodyText,
    bodyPossiblyIncomplete:
        bodyPossiblyIncomplete ?? this.bodyPossiblyIncomplete,
    links: links.present ? links.value : this.links,
    bodyClearedAt: bodyClearedAt.present
        ? bodyClearedAt.value
        : this.bodyClearedAt,
    analysisStatus: analysisStatus ?? this.analysisStatus,
    analysisFailureType: analysisFailureType.present
        ? analysisFailureType.value
        : this.analysisFailureType,
    analysisFailureCount: analysisFailureCount ?? this.analysisFailureCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    category: category.present ? category.value : this.category,
    categoryReason: categoryReason.present
        ? categoryReason.value
        : this.categoryReason,
    markedUseful: markedUseful ?? this.markedUseful,
    sourceFileId: sourceFileId ?? this.sourceFileId,
    importedAt: importedAt ?? this.importedAt,
    analyzedAt: analyzedAt.present ? analyzedAt.value : this.analyzedAt,
  );
  MailRow copyWithCompanion(MailsCompanion data) {
    return MailRow(
      id: data.id.present ? data.id.value : this.id,
      mailbox: data.mailbox.present ? data.mailbox.value : this.mailbox,
      mailKey: data.mailKey.present ? data.mailKey.value : this.mailKey,
      mailKeyKind: data.mailKeyKind.present
          ? data.mailKeyKind.value
          : this.mailKeyKind,
      outlookId: data.outlookId.present ? data.outlookId.value : this.outlookId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      subject: data.subject.present ? data.subject.value : this.subject,
      senderName: data.senderName.present
          ? data.senderName.value
          : this.senderName,
      senderAddress: data.senderAddress.present
          ? data.senderAddress.value
          : this.senderAddress,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
      hasAttachments: data.hasAttachments.present
          ? data.hasAttachments.value
          : this.hasAttachments,
      hasInlineImages: data.hasInlineImages.present
          ? data.hasInlineImages.value
          : this.hasInlineImages,
      bodyText: data.bodyText.present ? data.bodyText.value : this.bodyText,
      bodyPossiblyIncomplete: data.bodyPossiblyIncomplete.present
          ? data.bodyPossiblyIncomplete.value
          : this.bodyPossiblyIncomplete,
      links: data.links.present ? data.links.value : this.links,
      bodyClearedAt: data.bodyClearedAt.present
          ? data.bodyClearedAt.value
          : this.bodyClearedAt,
      analysisStatus: data.analysisStatus.present
          ? data.analysisStatus.value
          : this.analysisStatus,
      analysisFailureType: data.analysisFailureType.present
          ? data.analysisFailureType.value
          : this.analysisFailureType,
      analysisFailureCount: data.analysisFailureCount.present
          ? data.analysisFailureCount.value
          : this.analysisFailureCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      category: data.category.present ? data.category.value : this.category,
      categoryReason: data.categoryReason.present
          ? data.categoryReason.value
          : this.categoryReason,
      markedUseful: data.markedUseful.present
          ? data.markedUseful.value
          : this.markedUseful,
      sourceFileId: data.sourceFileId.present
          ? data.sourceFileId.value
          : this.sourceFileId,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      analyzedAt: data.analyzedAt.present
          ? data.analyzedAt.value
          : this.analyzedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MailRow(')
          ..write('id: $id, ')
          ..write('mailbox: $mailbox, ')
          ..write('mailKey: $mailKey, ')
          ..write('mailKeyKind: $mailKeyKind, ')
          ..write('outlookId: $outlookId, ')
          ..write('conversationId: $conversationId, ')
          ..write('subject: $subject, ')
          ..write('senderName: $senderName, ')
          ..write('senderAddress: $senderAddress, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('importance: $importance, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('hasInlineImages: $hasInlineImages, ')
          ..write('bodyText: $bodyText, ')
          ..write('bodyPossiblyIncomplete: $bodyPossiblyIncomplete, ')
          ..write('links: $links, ')
          ..write('bodyClearedAt: $bodyClearedAt, ')
          ..write('analysisStatus: $analysisStatus, ')
          ..write('analysisFailureType: $analysisFailureType, ')
          ..write('analysisFailureCount: $analysisFailureCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('category: $category, ')
          ..write('categoryReason: $categoryReason, ')
          ..write('markedUseful: $markedUseful, ')
          ..write('sourceFileId: $sourceFileId, ')
          ..write('importedAt: $importedAt, ')
          ..write('analyzedAt: $analyzedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    mailbox,
    mailKey,
    mailKeyKind,
    outlookId,
    conversationId,
    subject,
    senderName,
    senderAddress,
    receivedAt,
    importance,
    hasAttachments,
    hasInlineImages,
    bodyText,
    bodyPossiblyIncomplete,
    links,
    bodyClearedAt,
    analysisStatus,
    analysisFailureType,
    analysisFailureCount,
    nextRetryAt,
    category,
    categoryReason,
    markedUseful,
    sourceFileId,
    importedAt,
    analyzedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MailRow &&
          other.id == this.id &&
          other.mailbox == this.mailbox &&
          other.mailKey == this.mailKey &&
          other.mailKeyKind == this.mailKeyKind &&
          other.outlookId == this.outlookId &&
          other.conversationId == this.conversationId &&
          other.subject == this.subject &&
          other.senderName == this.senderName &&
          other.senderAddress == this.senderAddress &&
          other.receivedAt == this.receivedAt &&
          other.importance == this.importance &&
          other.hasAttachments == this.hasAttachments &&
          other.hasInlineImages == this.hasInlineImages &&
          other.bodyText == this.bodyText &&
          other.bodyPossiblyIncomplete == this.bodyPossiblyIncomplete &&
          other.links == this.links &&
          other.bodyClearedAt == this.bodyClearedAt &&
          other.analysisStatus == this.analysisStatus &&
          other.analysisFailureType == this.analysisFailureType &&
          other.analysisFailureCount == this.analysisFailureCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.category == this.category &&
          other.categoryReason == this.categoryReason &&
          other.markedUseful == this.markedUseful &&
          other.sourceFileId == this.sourceFileId &&
          other.importedAt == this.importedAt &&
          other.analyzedAt == this.analyzedAt);
}

class MailsCompanion extends UpdateCompanion<MailRow> {
  final Value<String> id;
  final Value<String> mailbox;
  final Value<String> mailKey;
  final Value<MailKeyKind> mailKeyKind;
  final Value<String?> outlookId;
  final Value<String?> conversationId;
  final Value<String> subject;
  final Value<String?> senderName;
  final Value<String?> senderAddress;
  final Value<int?> receivedAt;
  final Value<String?> importance;
  final Value<bool> hasAttachments;
  final Value<bool> hasInlineImages;
  final Value<String?> bodyText;
  final Value<bool> bodyPossiblyIncomplete;
  final Value<String?> links;
  final Value<int?> bodyClearedAt;
  final Value<MailAnalysisStatus> analysisStatus;
  final Value<String?> analysisFailureType;
  final Value<int> analysisFailureCount;
  final Value<int?> nextRetryAt;
  final Value<String?> category;
  final Value<String?> categoryReason;
  final Value<bool> markedUseful;
  final Value<String> sourceFileId;
  final Value<int> importedAt;
  final Value<int?> analyzedAt;
  final Value<int> rowid;
  const MailsCompanion({
    this.id = const Value.absent(),
    this.mailbox = const Value.absent(),
    this.mailKey = const Value.absent(),
    this.mailKeyKind = const Value.absent(),
    this.outlookId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.subject = const Value.absent(),
    this.senderName = const Value.absent(),
    this.senderAddress = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.importance = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.hasInlineImages = const Value.absent(),
    this.bodyText = const Value.absent(),
    this.bodyPossiblyIncomplete = const Value.absent(),
    this.links = const Value.absent(),
    this.bodyClearedAt = const Value.absent(),
    this.analysisStatus = const Value.absent(),
    this.analysisFailureType = const Value.absent(),
    this.analysisFailureCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.category = const Value.absent(),
    this.categoryReason = const Value.absent(),
    this.markedUseful = const Value.absent(),
    this.sourceFileId = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.analyzedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MailsCompanion.insert({
    required String id,
    required String mailbox,
    required String mailKey,
    required MailKeyKind mailKeyKind,
    this.outlookId = const Value.absent(),
    this.conversationId = const Value.absent(),
    required String subject,
    this.senderName = const Value.absent(),
    this.senderAddress = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.importance = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.hasInlineImages = const Value.absent(),
    this.bodyText = const Value.absent(),
    this.bodyPossiblyIncomplete = const Value.absent(),
    this.links = const Value.absent(),
    this.bodyClearedAt = const Value.absent(),
    required MailAnalysisStatus analysisStatus,
    this.analysisFailureType = const Value.absent(),
    this.analysisFailureCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.category = const Value.absent(),
    this.categoryReason = const Value.absent(),
    this.markedUseful = const Value.absent(),
    required String sourceFileId,
    required int importedAt,
    this.analyzedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mailbox = Value(mailbox),
       mailKey = Value(mailKey),
       mailKeyKind = Value(mailKeyKind),
       subject = Value(subject),
       analysisStatus = Value(analysisStatus),
       sourceFileId = Value(sourceFileId),
       importedAt = Value(importedAt);
  static Insertable<MailRow> custom({
    Expression<String>? id,
    Expression<String>? mailbox,
    Expression<String>? mailKey,
    Expression<String>? mailKeyKind,
    Expression<String>? outlookId,
    Expression<String>? conversationId,
    Expression<String>? subject,
    Expression<String>? senderName,
    Expression<String>? senderAddress,
    Expression<int>? receivedAt,
    Expression<String>? importance,
    Expression<bool>? hasAttachments,
    Expression<bool>? hasInlineImages,
    Expression<String>? bodyText,
    Expression<bool>? bodyPossiblyIncomplete,
    Expression<String>? links,
    Expression<int>? bodyClearedAt,
    Expression<String>? analysisStatus,
    Expression<String>? analysisFailureType,
    Expression<int>? analysisFailureCount,
    Expression<int>? nextRetryAt,
    Expression<String>? category,
    Expression<String>? categoryReason,
    Expression<bool>? markedUseful,
    Expression<String>? sourceFileId,
    Expression<int>? importedAt,
    Expression<int>? analyzedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mailbox != null) 'mailbox': mailbox,
      if (mailKey != null) 'mail_key': mailKey,
      if (mailKeyKind != null) 'mail_key_kind': mailKeyKind,
      if (outlookId != null) 'outlook_id': outlookId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (subject != null) 'subject': subject,
      if (senderName != null) 'sender_name': senderName,
      if (senderAddress != null) 'sender_address': senderAddress,
      if (receivedAt != null) 'received_at': receivedAt,
      if (importance != null) 'importance': importance,
      if (hasAttachments != null) 'has_attachments': hasAttachments,
      if (hasInlineImages != null) 'has_inline_images': hasInlineImages,
      if (bodyText != null) 'body_text': bodyText,
      if (bodyPossiblyIncomplete != null)
        'body_possibly_incomplete': bodyPossiblyIncomplete,
      if (links != null) 'links': links,
      if (bodyClearedAt != null) 'body_cleared_at': bodyClearedAt,
      if (analysisStatus != null) 'analysis_status': analysisStatus,
      if (analysisFailureType != null)
        'analysis_failure_type': analysisFailureType,
      if (analysisFailureCount != null)
        'analysis_failure_count': analysisFailureCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (category != null) 'category': category,
      if (categoryReason != null) 'category_reason': categoryReason,
      if (markedUseful != null) 'marked_useful': markedUseful,
      if (sourceFileId != null) 'source_file_id': sourceFileId,
      if (importedAt != null) 'imported_at': importedAt,
      if (analyzedAt != null) 'analyzed_at': analyzedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MailsCompanion copyWith({
    Value<String>? id,
    Value<String>? mailbox,
    Value<String>? mailKey,
    Value<MailKeyKind>? mailKeyKind,
    Value<String?>? outlookId,
    Value<String?>? conversationId,
    Value<String>? subject,
    Value<String?>? senderName,
    Value<String?>? senderAddress,
    Value<int?>? receivedAt,
    Value<String?>? importance,
    Value<bool>? hasAttachments,
    Value<bool>? hasInlineImages,
    Value<String?>? bodyText,
    Value<bool>? bodyPossiblyIncomplete,
    Value<String?>? links,
    Value<int?>? bodyClearedAt,
    Value<MailAnalysisStatus>? analysisStatus,
    Value<String?>? analysisFailureType,
    Value<int>? analysisFailureCount,
    Value<int?>? nextRetryAt,
    Value<String?>? category,
    Value<String?>? categoryReason,
    Value<bool>? markedUseful,
    Value<String>? sourceFileId,
    Value<int>? importedAt,
    Value<int?>? analyzedAt,
    Value<int>? rowid,
  }) {
    return MailsCompanion(
      id: id ?? this.id,
      mailbox: mailbox ?? this.mailbox,
      mailKey: mailKey ?? this.mailKey,
      mailKeyKind: mailKeyKind ?? this.mailKeyKind,
      outlookId: outlookId ?? this.outlookId,
      conversationId: conversationId ?? this.conversationId,
      subject: subject ?? this.subject,
      senderName: senderName ?? this.senderName,
      senderAddress: senderAddress ?? this.senderAddress,
      receivedAt: receivedAt ?? this.receivedAt,
      importance: importance ?? this.importance,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      hasInlineImages: hasInlineImages ?? this.hasInlineImages,
      bodyText: bodyText ?? this.bodyText,
      bodyPossiblyIncomplete:
          bodyPossiblyIncomplete ?? this.bodyPossiblyIncomplete,
      links: links ?? this.links,
      bodyClearedAt: bodyClearedAt ?? this.bodyClearedAt,
      analysisStatus: analysisStatus ?? this.analysisStatus,
      analysisFailureType: analysisFailureType ?? this.analysisFailureType,
      analysisFailureCount: analysisFailureCount ?? this.analysisFailureCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      category: category ?? this.category,
      categoryReason: categoryReason ?? this.categoryReason,
      markedUseful: markedUseful ?? this.markedUseful,
      sourceFileId: sourceFileId ?? this.sourceFileId,
      importedAt: importedAt ?? this.importedAt,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mailbox.present) {
      map['mailbox'] = Variable<String>(mailbox.value);
    }
    if (mailKey.present) {
      map['mail_key'] = Variable<String>(mailKey.value);
    }
    if (mailKeyKind.present) {
      map['mail_key_kind'] = Variable<String>(
        $MailsTable.$convertermailKeyKind.toSql(mailKeyKind.value),
      );
    }
    if (outlookId.present) {
      map['outlook_id'] = Variable<String>(outlookId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (senderAddress.present) {
      map['sender_address'] = Variable<String>(senderAddress.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<int>(receivedAt.value);
    }
    if (importance.present) {
      map['importance'] = Variable<String>(importance.value);
    }
    if (hasAttachments.present) {
      map['has_attachments'] = Variable<bool>(hasAttachments.value);
    }
    if (hasInlineImages.present) {
      map['has_inline_images'] = Variable<bool>(hasInlineImages.value);
    }
    if (bodyText.present) {
      map['body_text'] = Variable<String>(bodyText.value);
    }
    if (bodyPossiblyIncomplete.present) {
      map['body_possibly_incomplete'] = Variable<bool>(
        bodyPossiblyIncomplete.value,
      );
    }
    if (links.present) {
      map['links'] = Variable<String>(links.value);
    }
    if (bodyClearedAt.present) {
      map['body_cleared_at'] = Variable<int>(bodyClearedAt.value);
    }
    if (analysisStatus.present) {
      map['analysis_status'] = Variable<String>(
        $MailsTable.$converteranalysisStatus.toSql(analysisStatus.value),
      );
    }
    if (analysisFailureType.present) {
      map['analysis_failure_type'] = Variable<String>(
        analysisFailureType.value,
      );
    }
    if (analysisFailureCount.present) {
      map['analysis_failure_count'] = Variable<int>(analysisFailureCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<int>(nextRetryAt.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (categoryReason.present) {
      map['category_reason'] = Variable<String>(categoryReason.value);
    }
    if (markedUseful.present) {
      map['marked_useful'] = Variable<bool>(markedUseful.value);
    }
    if (sourceFileId.present) {
      map['source_file_id'] = Variable<String>(sourceFileId.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<int>(importedAt.value);
    }
    if (analyzedAt.present) {
      map['analyzed_at'] = Variable<int>(analyzedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MailsCompanion(')
          ..write('id: $id, ')
          ..write('mailbox: $mailbox, ')
          ..write('mailKey: $mailKey, ')
          ..write('mailKeyKind: $mailKeyKind, ')
          ..write('outlookId: $outlookId, ')
          ..write('conversationId: $conversationId, ')
          ..write('subject: $subject, ')
          ..write('senderName: $senderName, ')
          ..write('senderAddress: $senderAddress, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('importance: $importance, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('hasInlineImages: $hasInlineImages, ')
          ..write('bodyText: $bodyText, ')
          ..write('bodyPossiblyIncomplete: $bodyPossiblyIncomplete, ')
          ..write('links: $links, ')
          ..write('bodyClearedAt: $bodyClearedAt, ')
          ..write('analysisStatus: $analysisStatus, ')
          ..write('analysisFailureType: $analysisFailureType, ')
          ..write('analysisFailureCount: $analysisFailureCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('category: $category, ')
          ..write('categoryReason: $categoryReason, ')
          ..write('markedUseful: $markedUseful, ')
          ..write('sourceFileId: $sourceFileId, ')
          ..write('importedAt: $importedAt, ')
          ..write('analyzedAt: $analyzedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MailItemsTable extends MailItems
    with TableInfo<$MailItemsTable, MailItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MailItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mailIdMeta = const VerificationMeta('mailId');
  @override
  late final GeneratedColumn<String> mailId = GeneratedColumn<String>(
    'mail_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mails (id)',
    ),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionsMeta = const VerificationMeta(
    'actions',
  );
  @override
  late final GeneratedColumn<String> actions = GeneratedColumn<String>(
    'actions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkRefsMeta = const VerificationMeta(
    'linkRefs',
  );
  @override
  late final GeneratedColumn<String> linkRefs = GeneratedColumn<String>(
    'link_refs',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventTimeMeta = const VerificationMeta(
    'eventTime',
  );
  @override
  late final GeneratedColumn<String> eventTime = GeneratedColumn<String>(
    'event_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardTimePrecision?, String>
  eventTimePrecision =
      GeneratedColumn<String>(
        'event_time_precision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CardTimePrecision?>(
        $MailItemsTable.$convertereventTimePrecisionn,
      );
  static const VerificationMeta _eventTimePendingMeta = const VerificationMeta(
    'eventTimePending',
  );
  @override
  late final GeneratedColumn<bool> eventTimePending = GeneratedColumn<bool>(
    'event_time_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("event_time_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dueTimeMeta = const VerificationMeta(
    'dueTime',
  );
  @override
  late final GeneratedColumn<String> dueTime = GeneratedColumn<String>(
    'due_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardTimePrecision?, String>
  dueTimePrecision =
      GeneratedColumn<String>(
        'due_time_precision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CardTimePrecision?>(
        $MailItemsTable.$converterdueTimePrecisionn,
      );
  static const VerificationMeta _dueTimePendingMeta = const VerificationMeta(
    'dueTimePending',
  );
  @override
  late final GeneratedColumn<bool> dueTimePending = GeneratedColumn<bool>(
    'due_time_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("due_time_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _optionalMeta = const VerificationMeta(
    'optional',
  );
  @override
  late final GeneratedColumn<bool> optional = GeneratedColumn<bool>(
    'optional',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("optional" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasUnanalyzedAttachmentsMeta =
      const VerificationMeta('hasUnanalyzedAttachments');
  @override
  late final GeneratedColumn<bool> hasUnanalyzedAttachments =
      GeneratedColumn<bool>(
        'has_unanalyzed_attachments',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("has_unanalyzed_attachments" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  late final GeneratedColumnWithTypeConverter<MailItemStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MailItemStatus>($MailItemsTable.$converterstatus);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_cards (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _updatedMeta = const VerificationMeta(
    'updated',
  );
  @override
  late final GeneratedColumn<bool> updated = GeneratedColumn<bool>(
    'updated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("updated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _relatedItemIdMeta = const VerificationMeta(
    'relatedItemId',
  );
  @override
  late final GeneratedColumn<String> relatedItemId = GeneratedColumn<String>(
    'related_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mail_items (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mailId,
    conversationId,
    title,
    summary,
    actions,
    location,
    linkRefs,
    eventTime,
    eventTimePrecision,
    eventTimePending,
    dueTime,
    dueTimePrecision,
    dueTimePending,
    optional,
    hasUnanalyzedAttachments,
    status,
    cardId,
    updated,
    relatedItemId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mail_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MailItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mail_id')) {
      context.handle(
        _mailIdMeta,
        mailId.isAcceptableOrUnknown(data['mail_id']!, _mailIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mailIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('actions')) {
      context.handle(
        _actionsMeta,
        actions.isAcceptableOrUnknown(data['actions']!, _actionsMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('link_refs')) {
      context.handle(
        _linkRefsMeta,
        linkRefs.isAcceptableOrUnknown(data['link_refs']!, _linkRefsMeta),
      );
    }
    if (data.containsKey('event_time')) {
      context.handle(
        _eventTimeMeta,
        eventTime.isAcceptableOrUnknown(data['event_time']!, _eventTimeMeta),
      );
    }
    if (data.containsKey('event_time_pending')) {
      context.handle(
        _eventTimePendingMeta,
        eventTimePending.isAcceptableOrUnknown(
          data['event_time_pending']!,
          _eventTimePendingMeta,
        ),
      );
    }
    if (data.containsKey('due_time')) {
      context.handle(
        _dueTimeMeta,
        dueTime.isAcceptableOrUnknown(data['due_time']!, _dueTimeMeta),
      );
    }
    if (data.containsKey('due_time_pending')) {
      context.handle(
        _dueTimePendingMeta,
        dueTimePending.isAcceptableOrUnknown(
          data['due_time_pending']!,
          _dueTimePendingMeta,
        ),
      );
    }
    if (data.containsKey('optional')) {
      context.handle(
        _optionalMeta,
        optional.isAcceptableOrUnknown(data['optional']!, _optionalMeta),
      );
    }
    if (data.containsKey('has_unanalyzed_attachments')) {
      context.handle(
        _hasUnanalyzedAttachmentsMeta,
        hasUnanalyzedAttachments.isAcceptableOrUnknown(
          data['has_unanalyzed_attachments']!,
          _hasUnanalyzedAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    }
    if (data.containsKey('updated')) {
      context.handle(
        _updatedMeta,
        updated.isAcceptableOrUnknown(data['updated']!, _updatedMeta),
      );
    }
    if (data.containsKey('related_item_id')) {
      context.handle(
        _relatedItemIdMeta,
        relatedItemId.isAcceptableOrUnknown(
          data['related_item_id']!,
          _relatedItemIdMeta,
        ),
      );
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
  MailItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MailItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mailId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mail_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      actions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actions'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      linkRefs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_refs'],
      ),
      eventTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_time'],
      ),
      eventTimePrecision: $MailItemsTable.$convertereventTimePrecisionn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}event_time_precision'],
        ),
      ),
      eventTimePending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}event_time_pending'],
      )!,
      dueTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_time'],
      ),
      dueTimePrecision: $MailItemsTable.$converterdueTimePrecisionn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}due_time_precision'],
        ),
      ),
      dueTimePending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}due_time_pending'],
      )!,
      optional: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}optional'],
      )!,
      hasUnanalyzedAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_unanalyzed_attachments'],
      )!,
      status: $MailItemsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      ),
      updated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}updated'],
      )!,
      relatedItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_item_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MailItemsTable createAlias(String alias) {
    return $MailItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CardTimePrecision, String, String>
  $convertereventTimePrecision = const EnumNameConverter<CardTimePrecision>(
    CardTimePrecision.values,
  );
  static JsonTypeConverter2<CardTimePrecision?, String?, String?>
  $convertereventTimePrecisionn = JsonTypeConverter2.asNullable(
    $convertereventTimePrecision,
  );
  static JsonTypeConverter2<CardTimePrecision, String, String>
  $converterdueTimePrecision = const EnumNameConverter<CardTimePrecision>(
    CardTimePrecision.values,
  );
  static JsonTypeConverter2<CardTimePrecision?, String?, String?>
  $converterdueTimePrecisionn = JsonTypeConverter2.asNullable(
    $converterdueTimePrecision,
  );
  static JsonTypeConverter2<MailItemStatus, String, String> $converterstatus =
      const EnumNameConverter<MailItemStatus>(MailItemStatus.values);
}

class MailItemRow extends DataClass implements Insertable<MailItemRow> {
  final String id;
  final String mailId;
  final String? conversationId;
  final String title;
  final String? summary;

  /// 要做的事，JSON 数组。
  final String? actions;
  final String? location;

  /// 引用的邮件链接下标，JSON 数组。
  final String? linkRefs;
  final String? eventTime;
  final CardTimePrecision? eventTimePrecision;
  final bool eventTimePending;
  final String? dueTime;
  final CardTimePrecision? dueTimePrecision;
  final bool dueTimePending;
  final bool optional;
  final bool hasUnanalyzedAttachments;
  final MailItemStatus status;

  /// 卡片被永久删除时置空。
  final String? cardId;
  final bool updated;
  final String? relatedItemId;
  final int createdAt;
  final int updatedAt;
  const MailItemRow({
    required this.id,
    required this.mailId,
    this.conversationId,
    required this.title,
    this.summary,
    this.actions,
    this.location,
    this.linkRefs,
    this.eventTime,
    this.eventTimePrecision,
    required this.eventTimePending,
    this.dueTime,
    this.dueTimePrecision,
    required this.dueTimePending,
    required this.optional,
    required this.hasUnanalyzedAttachments,
    required this.status,
    this.cardId,
    required this.updated,
    this.relatedItemId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mail_id'] = Variable<String>(mailId);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || actions != null) {
      map['actions'] = Variable<String>(actions);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || linkRefs != null) {
      map['link_refs'] = Variable<String>(linkRefs);
    }
    if (!nullToAbsent || eventTime != null) {
      map['event_time'] = Variable<String>(eventTime);
    }
    if (!nullToAbsent || eventTimePrecision != null) {
      map['event_time_precision'] = Variable<String>(
        $MailItemsTable.$convertereventTimePrecisionn.toSql(eventTimePrecision),
      );
    }
    map['event_time_pending'] = Variable<bool>(eventTimePending);
    if (!nullToAbsent || dueTime != null) {
      map['due_time'] = Variable<String>(dueTime);
    }
    if (!nullToAbsent || dueTimePrecision != null) {
      map['due_time_precision'] = Variable<String>(
        $MailItemsTable.$converterdueTimePrecisionn.toSql(dueTimePrecision),
      );
    }
    map['due_time_pending'] = Variable<bool>(dueTimePending);
    map['optional'] = Variable<bool>(optional);
    map['has_unanalyzed_attachments'] = Variable<bool>(
      hasUnanalyzedAttachments,
    );
    {
      map['status'] = Variable<String>(
        $MailItemsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || cardId != null) {
      map['card_id'] = Variable<String>(cardId);
    }
    map['updated'] = Variable<bool>(updated);
    if (!nullToAbsent || relatedItemId != null) {
      map['related_item_id'] = Variable<String>(relatedItemId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MailItemsCompanion toCompanion(bool nullToAbsent) {
    return MailItemsCompanion(
      id: Value(id),
      mailId: Value(mailId),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      title: Value(title),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      actions: actions == null && nullToAbsent
          ? const Value.absent()
          : Value(actions),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      linkRefs: linkRefs == null && nullToAbsent
          ? const Value.absent()
          : Value(linkRefs),
      eventTime: eventTime == null && nullToAbsent
          ? const Value.absent()
          : Value(eventTime),
      eventTimePrecision: eventTimePrecision == null && nullToAbsent
          ? const Value.absent()
          : Value(eventTimePrecision),
      eventTimePending: Value(eventTimePending),
      dueTime: dueTime == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTime),
      dueTimePrecision: dueTimePrecision == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTimePrecision),
      dueTimePending: Value(dueTimePending),
      optional: Value(optional),
      hasUnanalyzedAttachments: Value(hasUnanalyzedAttachments),
      status: Value(status),
      cardId: cardId == null && nullToAbsent
          ? const Value.absent()
          : Value(cardId),
      updated: Value(updated),
      relatedItemId: relatedItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedItemId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MailItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MailItemRow(
      id: serializer.fromJson<String>(json['id']),
      mailId: serializer.fromJson<String>(json['mailId']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String?>(json['summary']),
      actions: serializer.fromJson<String?>(json['actions']),
      location: serializer.fromJson<String?>(json['location']),
      linkRefs: serializer.fromJson<String?>(json['linkRefs']),
      eventTime: serializer.fromJson<String?>(json['eventTime']),
      eventTimePrecision: $MailItemsTable.$convertereventTimePrecisionn
          .fromJson(serializer.fromJson<String?>(json['eventTimePrecision'])),
      eventTimePending: serializer.fromJson<bool>(json['eventTimePending']),
      dueTime: serializer.fromJson<String?>(json['dueTime']),
      dueTimePrecision: $MailItemsTable.$converterdueTimePrecisionn.fromJson(
        serializer.fromJson<String?>(json['dueTimePrecision']),
      ),
      dueTimePending: serializer.fromJson<bool>(json['dueTimePending']),
      optional: serializer.fromJson<bool>(json['optional']),
      hasUnanalyzedAttachments: serializer.fromJson<bool>(
        json['hasUnanalyzedAttachments'],
      ),
      status: $MailItemsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      cardId: serializer.fromJson<String?>(json['cardId']),
      updated: serializer.fromJson<bool>(json['updated']),
      relatedItemId: serializer.fromJson<String?>(json['relatedItemId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mailId': serializer.toJson<String>(mailId),
      'conversationId': serializer.toJson<String?>(conversationId),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String?>(summary),
      'actions': serializer.toJson<String?>(actions),
      'location': serializer.toJson<String?>(location),
      'linkRefs': serializer.toJson<String?>(linkRefs),
      'eventTime': serializer.toJson<String?>(eventTime),
      'eventTimePrecision': serializer.toJson<String?>(
        $MailItemsTable.$convertereventTimePrecisionn.toJson(
          eventTimePrecision,
        ),
      ),
      'eventTimePending': serializer.toJson<bool>(eventTimePending),
      'dueTime': serializer.toJson<String?>(dueTime),
      'dueTimePrecision': serializer.toJson<String?>(
        $MailItemsTable.$converterdueTimePrecisionn.toJson(dueTimePrecision),
      ),
      'dueTimePending': serializer.toJson<bool>(dueTimePending),
      'optional': serializer.toJson<bool>(optional),
      'hasUnanalyzedAttachments': serializer.toJson<bool>(
        hasUnanalyzedAttachments,
      ),
      'status': serializer.toJson<String>(
        $MailItemsTable.$converterstatus.toJson(status),
      ),
      'cardId': serializer.toJson<String?>(cardId),
      'updated': serializer.toJson<bool>(updated),
      'relatedItemId': serializer.toJson<String?>(relatedItemId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MailItemRow copyWith({
    String? id,
    String? mailId,
    Value<String?> conversationId = const Value.absent(),
    String? title,
    Value<String?> summary = const Value.absent(),
    Value<String?> actions = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<String?> linkRefs = const Value.absent(),
    Value<String?> eventTime = const Value.absent(),
    Value<CardTimePrecision?> eventTimePrecision = const Value.absent(),
    bool? eventTimePending,
    Value<String?> dueTime = const Value.absent(),
    Value<CardTimePrecision?> dueTimePrecision = const Value.absent(),
    bool? dueTimePending,
    bool? optional,
    bool? hasUnanalyzedAttachments,
    MailItemStatus? status,
    Value<String?> cardId = const Value.absent(),
    bool? updated,
    Value<String?> relatedItemId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => MailItemRow(
    id: id ?? this.id,
    mailId: mailId ?? this.mailId,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    title: title ?? this.title,
    summary: summary.present ? summary.value : this.summary,
    actions: actions.present ? actions.value : this.actions,
    location: location.present ? location.value : this.location,
    linkRefs: linkRefs.present ? linkRefs.value : this.linkRefs,
    eventTime: eventTime.present ? eventTime.value : this.eventTime,
    eventTimePrecision: eventTimePrecision.present
        ? eventTimePrecision.value
        : this.eventTimePrecision,
    eventTimePending: eventTimePending ?? this.eventTimePending,
    dueTime: dueTime.present ? dueTime.value : this.dueTime,
    dueTimePrecision: dueTimePrecision.present
        ? dueTimePrecision.value
        : this.dueTimePrecision,
    dueTimePending: dueTimePending ?? this.dueTimePending,
    optional: optional ?? this.optional,
    hasUnanalyzedAttachments:
        hasUnanalyzedAttachments ?? this.hasUnanalyzedAttachments,
    status: status ?? this.status,
    cardId: cardId.present ? cardId.value : this.cardId,
    updated: updated ?? this.updated,
    relatedItemId: relatedItemId.present
        ? relatedItemId.value
        : this.relatedItemId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MailItemRow copyWithCompanion(MailItemsCompanion data) {
    return MailItemRow(
      id: data.id.present ? data.id.value : this.id,
      mailId: data.mailId.present ? data.mailId.value : this.mailId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      actions: data.actions.present ? data.actions.value : this.actions,
      location: data.location.present ? data.location.value : this.location,
      linkRefs: data.linkRefs.present ? data.linkRefs.value : this.linkRefs,
      eventTime: data.eventTime.present ? data.eventTime.value : this.eventTime,
      eventTimePrecision: data.eventTimePrecision.present
          ? data.eventTimePrecision.value
          : this.eventTimePrecision,
      eventTimePending: data.eventTimePending.present
          ? data.eventTimePending.value
          : this.eventTimePending,
      dueTime: data.dueTime.present ? data.dueTime.value : this.dueTime,
      dueTimePrecision: data.dueTimePrecision.present
          ? data.dueTimePrecision.value
          : this.dueTimePrecision,
      dueTimePending: data.dueTimePending.present
          ? data.dueTimePending.value
          : this.dueTimePending,
      optional: data.optional.present ? data.optional.value : this.optional,
      hasUnanalyzedAttachments: data.hasUnanalyzedAttachments.present
          ? data.hasUnanalyzedAttachments.value
          : this.hasUnanalyzedAttachments,
      status: data.status.present ? data.status.value : this.status,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      updated: data.updated.present ? data.updated.value : this.updated,
      relatedItemId: data.relatedItemId.present
          ? data.relatedItemId.value
          : this.relatedItemId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MailItemRow(')
          ..write('id: $id, ')
          ..write('mailId: $mailId, ')
          ..write('conversationId: $conversationId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('actions: $actions, ')
          ..write('location: $location, ')
          ..write('linkRefs: $linkRefs, ')
          ..write('eventTime: $eventTime, ')
          ..write('eventTimePrecision: $eventTimePrecision, ')
          ..write('eventTimePending: $eventTimePending, ')
          ..write('dueTime: $dueTime, ')
          ..write('dueTimePrecision: $dueTimePrecision, ')
          ..write('dueTimePending: $dueTimePending, ')
          ..write('optional: $optional, ')
          ..write('hasUnanalyzedAttachments: $hasUnanalyzedAttachments, ')
          ..write('status: $status, ')
          ..write('cardId: $cardId, ')
          ..write('updated: $updated, ')
          ..write('relatedItemId: $relatedItemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    mailId,
    conversationId,
    title,
    summary,
    actions,
    location,
    linkRefs,
    eventTime,
    eventTimePrecision,
    eventTimePending,
    dueTime,
    dueTimePrecision,
    dueTimePending,
    optional,
    hasUnanalyzedAttachments,
    status,
    cardId,
    updated,
    relatedItemId,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MailItemRow &&
          other.id == this.id &&
          other.mailId == this.mailId &&
          other.conversationId == this.conversationId &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.actions == this.actions &&
          other.location == this.location &&
          other.linkRefs == this.linkRefs &&
          other.eventTime == this.eventTime &&
          other.eventTimePrecision == this.eventTimePrecision &&
          other.eventTimePending == this.eventTimePending &&
          other.dueTime == this.dueTime &&
          other.dueTimePrecision == this.dueTimePrecision &&
          other.dueTimePending == this.dueTimePending &&
          other.optional == this.optional &&
          other.hasUnanalyzedAttachments == this.hasUnanalyzedAttachments &&
          other.status == this.status &&
          other.cardId == this.cardId &&
          other.updated == this.updated &&
          other.relatedItemId == this.relatedItemId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MailItemsCompanion extends UpdateCompanion<MailItemRow> {
  final Value<String> id;
  final Value<String> mailId;
  final Value<String?> conversationId;
  final Value<String> title;
  final Value<String?> summary;
  final Value<String?> actions;
  final Value<String?> location;
  final Value<String?> linkRefs;
  final Value<String?> eventTime;
  final Value<CardTimePrecision?> eventTimePrecision;
  final Value<bool> eventTimePending;
  final Value<String?> dueTime;
  final Value<CardTimePrecision?> dueTimePrecision;
  final Value<bool> dueTimePending;
  final Value<bool> optional;
  final Value<bool> hasUnanalyzedAttachments;
  final Value<MailItemStatus> status;
  final Value<String?> cardId;
  final Value<bool> updated;
  final Value<String?> relatedItemId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MailItemsCompanion({
    this.id = const Value.absent(),
    this.mailId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.actions = const Value.absent(),
    this.location = const Value.absent(),
    this.linkRefs = const Value.absent(),
    this.eventTime = const Value.absent(),
    this.eventTimePrecision = const Value.absent(),
    this.eventTimePending = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.dueTimePrecision = const Value.absent(),
    this.dueTimePending = const Value.absent(),
    this.optional = const Value.absent(),
    this.hasUnanalyzedAttachments = const Value.absent(),
    this.status = const Value.absent(),
    this.cardId = const Value.absent(),
    this.updated = const Value.absent(),
    this.relatedItemId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MailItemsCompanion.insert({
    required String id,
    required String mailId,
    this.conversationId = const Value.absent(),
    required String title,
    this.summary = const Value.absent(),
    this.actions = const Value.absent(),
    this.location = const Value.absent(),
    this.linkRefs = const Value.absent(),
    this.eventTime = const Value.absent(),
    this.eventTimePrecision = const Value.absent(),
    this.eventTimePending = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.dueTimePrecision = const Value.absent(),
    this.dueTimePending = const Value.absent(),
    this.optional = const Value.absent(),
    this.hasUnanalyzedAttachments = const Value.absent(),
    required MailItemStatus status,
    this.cardId = const Value.absent(),
    this.updated = const Value.absent(),
    this.relatedItemId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mailId = Value(mailId),
       title = Value(title),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MailItemRow> custom({
    Expression<String>? id,
    Expression<String>? mailId,
    Expression<String>? conversationId,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? actions,
    Expression<String>? location,
    Expression<String>? linkRefs,
    Expression<String>? eventTime,
    Expression<String>? eventTimePrecision,
    Expression<bool>? eventTimePending,
    Expression<String>? dueTime,
    Expression<String>? dueTimePrecision,
    Expression<bool>? dueTimePending,
    Expression<bool>? optional,
    Expression<bool>? hasUnanalyzedAttachments,
    Expression<String>? status,
    Expression<String>? cardId,
    Expression<bool>? updated,
    Expression<String>? relatedItemId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mailId != null) 'mail_id': mailId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (actions != null) 'actions': actions,
      if (location != null) 'location': location,
      if (linkRefs != null) 'link_refs': linkRefs,
      if (eventTime != null) 'event_time': eventTime,
      if (eventTimePrecision != null)
        'event_time_precision': eventTimePrecision,
      if (eventTimePending != null) 'event_time_pending': eventTimePending,
      if (dueTime != null) 'due_time': dueTime,
      if (dueTimePrecision != null) 'due_time_precision': dueTimePrecision,
      if (dueTimePending != null) 'due_time_pending': dueTimePending,
      if (optional != null) 'optional': optional,
      if (hasUnanalyzedAttachments != null)
        'has_unanalyzed_attachments': hasUnanalyzedAttachments,
      if (status != null) 'status': status,
      if (cardId != null) 'card_id': cardId,
      if (updated != null) 'updated': updated,
      if (relatedItemId != null) 'related_item_id': relatedItemId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MailItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? mailId,
    Value<String?>? conversationId,
    Value<String>? title,
    Value<String?>? summary,
    Value<String?>? actions,
    Value<String?>? location,
    Value<String?>? linkRefs,
    Value<String?>? eventTime,
    Value<CardTimePrecision?>? eventTimePrecision,
    Value<bool>? eventTimePending,
    Value<String?>? dueTime,
    Value<CardTimePrecision?>? dueTimePrecision,
    Value<bool>? dueTimePending,
    Value<bool>? optional,
    Value<bool>? hasUnanalyzedAttachments,
    Value<MailItemStatus>? status,
    Value<String?>? cardId,
    Value<bool>? updated,
    Value<String?>? relatedItemId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MailItemsCompanion(
      id: id ?? this.id,
      mailId: mailId ?? this.mailId,
      conversationId: conversationId ?? this.conversationId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      actions: actions ?? this.actions,
      location: location ?? this.location,
      linkRefs: linkRefs ?? this.linkRefs,
      eventTime: eventTime ?? this.eventTime,
      eventTimePrecision: eventTimePrecision ?? this.eventTimePrecision,
      eventTimePending: eventTimePending ?? this.eventTimePending,
      dueTime: dueTime ?? this.dueTime,
      dueTimePrecision: dueTimePrecision ?? this.dueTimePrecision,
      dueTimePending: dueTimePending ?? this.dueTimePending,
      optional: optional ?? this.optional,
      hasUnanalyzedAttachments:
          hasUnanalyzedAttachments ?? this.hasUnanalyzedAttachments,
      status: status ?? this.status,
      cardId: cardId ?? this.cardId,
      updated: updated ?? this.updated,
      relatedItemId: relatedItemId ?? this.relatedItemId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mailId.present) {
      map['mail_id'] = Variable<String>(mailId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (actions.present) {
      map['actions'] = Variable<String>(actions.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (linkRefs.present) {
      map['link_refs'] = Variable<String>(linkRefs.value);
    }
    if (eventTime.present) {
      map['event_time'] = Variable<String>(eventTime.value);
    }
    if (eventTimePrecision.present) {
      map['event_time_precision'] = Variable<String>(
        $MailItemsTable.$convertereventTimePrecisionn.toSql(
          eventTimePrecision.value,
        ),
      );
    }
    if (eventTimePending.present) {
      map['event_time_pending'] = Variable<bool>(eventTimePending.value);
    }
    if (dueTime.present) {
      map['due_time'] = Variable<String>(dueTime.value);
    }
    if (dueTimePrecision.present) {
      map['due_time_precision'] = Variable<String>(
        $MailItemsTable.$converterdueTimePrecisionn.toSql(
          dueTimePrecision.value,
        ),
      );
    }
    if (dueTimePending.present) {
      map['due_time_pending'] = Variable<bool>(dueTimePending.value);
    }
    if (optional.present) {
      map['optional'] = Variable<bool>(optional.value);
    }
    if (hasUnanalyzedAttachments.present) {
      map['has_unanalyzed_attachments'] = Variable<bool>(
        hasUnanalyzedAttachments.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MailItemsTable.$converterstatus.toSql(status.value),
      );
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (updated.present) {
      map['updated'] = Variable<bool>(updated.value);
    }
    if (relatedItemId.present) {
      map['related_item_id'] = Variable<String>(relatedItemId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MailItemsCompanion(')
          ..write('id: $id, ')
          ..write('mailId: $mailId, ')
          ..write('conversationId: $conversationId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('actions: $actions, ')
          ..write('location: $location, ')
          ..write('linkRefs: $linkRefs, ')
          ..write('eventTime: $eventTime, ')
          ..write('eventTimePrecision: $eventTimePrecision, ')
          ..write('eventTimePending: $eventTimePending, ')
          ..write('dueTime: $dueTime, ')
          ..write('dueTimePrecision: $dueTimePrecision, ')
          ..write('dueTimePending: $dueTimePending, ')
          ..write('optional: $optional, ')
          ..write('hasUnanalyzedAttachments: $hasUnanalyzedAttachments, ')
          ..write('status: $status, ')
          ..write('cardId: $cardId, ')
          ..write('updated: $updated, ')
          ..write('relatedItemId: $relatedItemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MailItemUpdatesTable extends MailItemUpdates
    with TableInfo<$MailItemUpdatesTable, MailItemUpdateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MailItemUpdatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mail_items (id)',
    ),
  );
  static const VerificationMeta _mailIdMeta = const VerificationMeta('mailId');
  @override
  late final GeneratedColumn<String> mailId = GeneratedColumn<String>(
    'mail_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mails (id)',
    ),
  );
  static const VerificationMeta _changesMeta = const VerificationMeta(
    'changes',
  );
  @override
  late final GeneratedColumn<String> changes = GeneratedColumn<String>(
    'changes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MailItemUpdateStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MailItemUpdateStatus>($MailItemUpdatesTable.$converterstatus);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<int> resolvedAt = GeneratedColumn<int>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    mailId,
    changes,
    status,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mail_item_updates';
  @override
  VerificationContext validateIntegrity(
    Insertable<MailItemUpdateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('mail_id')) {
      context.handle(
        _mailIdMeta,
        mailId.isAcceptableOrUnknown(data['mail_id']!, _mailIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mailIdMeta);
    }
    if (data.containsKey('changes')) {
      context.handle(
        _changesMeta,
        changes.isAcceptableOrUnknown(data['changes']!, _changesMeta),
      );
    } else if (isInserting) {
      context.missing(_changesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MailItemUpdateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MailItemUpdateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      mailId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mail_id'],
      )!,
      changes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changes'],
      )!,
      status: $MailItemUpdatesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $MailItemUpdatesTable createAlias(String alias) {
    return $MailItemUpdatesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MailItemUpdateStatus, String, String>
  $converterstatus = const EnumNameConverter<MailItemUpdateStatus>(
    MailItemUpdateStatus.values,
  );
}

class MailItemUpdateRow extends DataClass
    implements Insertable<MailItemUpdateRow> {
  final String id;
  final String itemId;
  final String mailId;

  /// 字段名到新值，JSON 对象。
  final String changes;
  final MailItemUpdateStatus status;
  final int createdAt;
  final int? resolvedAt;
  const MailItemUpdateRow({
    required this.id,
    required this.itemId,
    required this.mailId,
    required this.changes,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['mail_id'] = Variable<String>(mailId);
    map['changes'] = Variable<String>(changes);
    {
      map['status'] = Variable<String>(
        $MailItemUpdatesTable.$converterstatus.toSql(status),
      );
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<int>(resolvedAt);
    }
    return map;
  }

  MailItemUpdatesCompanion toCompanion(bool nullToAbsent) {
    return MailItemUpdatesCompanion(
      id: Value(id),
      itemId: Value(itemId),
      mailId: Value(mailId),
      changes: Value(changes),
      status: Value(status),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory MailItemUpdateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MailItemUpdateRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      mailId: serializer.fromJson<String>(json['mailId']),
      changes: serializer.fromJson<String>(json['changes']),
      status: $MailItemUpdatesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      resolvedAt: serializer.fromJson<int?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'mailId': serializer.toJson<String>(mailId),
      'changes': serializer.toJson<String>(changes),
      'status': serializer.toJson<String>(
        $MailItemUpdatesTable.$converterstatus.toJson(status),
      ),
      'createdAt': serializer.toJson<int>(createdAt),
      'resolvedAt': serializer.toJson<int?>(resolvedAt),
    };
  }

  MailItemUpdateRow copyWith({
    String? id,
    String? itemId,
    String? mailId,
    String? changes,
    MailItemUpdateStatus? status,
    int? createdAt,
    Value<int?> resolvedAt = const Value.absent(),
  }) => MailItemUpdateRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    mailId: mailId ?? this.mailId,
    changes: changes ?? this.changes,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  MailItemUpdateRow copyWithCompanion(MailItemUpdatesCompanion data) {
    return MailItemUpdateRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      mailId: data.mailId.present ? data.mailId.value : this.mailId,
      changes: data.changes.present ? data.changes.value : this.changes,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MailItemUpdateRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('mailId: $mailId, ')
          ..write('changes: $changes, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, itemId, mailId, changes, status, createdAt, resolvedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MailItemUpdateRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.mailId == this.mailId &&
          other.changes == this.changes &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class MailItemUpdatesCompanion extends UpdateCompanion<MailItemUpdateRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> mailId;
  final Value<String> changes;
  final Value<MailItemUpdateStatus> status;
  final Value<int> createdAt;
  final Value<int?> resolvedAt;
  final Value<int> rowid;
  const MailItemUpdatesCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.mailId = const Value.absent(),
    this.changes = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MailItemUpdatesCompanion.insert({
    required String id,
    required String itemId,
    required String mailId,
    required String changes,
    required MailItemUpdateStatus status,
    required int createdAt,
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       mailId = Value(mailId),
       changes = Value(changes),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<MailItemUpdateRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? mailId,
    Expression<String>? changes,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (mailId != null) 'mail_id': mailId,
      if (changes != null) 'changes': changes,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MailItemUpdatesCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? mailId,
    Value<String>? changes,
    Value<MailItemUpdateStatus>? status,
    Value<int>? createdAt,
    Value<int?>? resolvedAt,
    Value<int>? rowid,
  }) {
    return MailItemUpdatesCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      mailId: mailId ?? this.mailId,
      changes: changes ?? this.changes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (mailId.present) {
      map['mail_id'] = Variable<String>(mailId.value);
    }
    if (changes.present) {
      map['changes'] = Variable<String>(changes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MailItemUpdatesTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<int>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MailItemUpdatesCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('mailId: $mailId, ')
          ..write('changes: $changes, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PlannerDatabase extends GeneratedDatabase {
  _$PlannerDatabase(QueryExecutor e) : super(e);
  late final $TaskCardsTable taskCards = $TaskCardsTable(this);
  late final $LinksTable links = $LinksTable(this);
  late final $CarryOverRecordsTable carryOverRecords = $CarryOverRecordsTable(
    this,
  );
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final $MailExportFilesTable mailExportFiles = $MailExportFilesTable(
    this,
  );
  late final $MailsTable mails = $MailsTable(this);
  late final $MailItemsTable mailItems = $MailItemsTable(this);
  late final $MailItemUpdatesTable mailItemUpdates = $MailItemUpdatesTable(
    this,
  );
  late final Index taskCardsDayKey = Index(
    'task_cards_day_key',
    'CREATE INDEX task_cards_day_key ON task_cards (day_key)',
  );
  late final Index linksOneActivePerPair = Index(
    'links_one_active_per_pair',
    'CREATE UNIQUE INDEX links_one_active_per_pair ON links (min(from_card_id, to_card_id), max(from_card_id, to_card_id)) WHERE deleted_at IS NULL',
  );
  late final Index carryOverRecordsFromDayKey = Index(
    'carry_over_records_from_day_key',
    'CREATE INDEX carry_over_records_from_day_key ON carry_over_records (from_day_key)',
  );
  late final Index mailsReceivedAt = Index(
    'mails_received_at',
    'CREATE INDEX mails_received_at ON mails (received_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    taskCards,
    links,
    carryOverRecords,
    appMeta,
    mailExportFiles,
    mails,
    mailItems,
    mailItemUpdates,
    taskCardsDayKey,
    linksOneActivePerPair,
    carryOverRecordsFromDayKey,
    mailsReceivedAt,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'task_cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mail_items', kind: UpdateKind.update)],
    ),
  ]);
}
