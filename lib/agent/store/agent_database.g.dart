// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_database.dart';

// ignore_for_file: type=lint
class $AgentConversationsTable extends AgentConversations
    with TableInfo<$AgentConversationsTable, StoredAgentConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hasPendingWorkMeta = const VerificationMeta(
    'hasPendingWork',
  );
  @override
  late final GeneratedColumn<bool> hasPendingWork = GeneratedColumn<bool>(
    'has_pending_work',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_pending_work" IN (0, 1))',
    ),
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    updatedAt,
    archived,
    hasPendingWork,
    metadata,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredAgentConversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    } else if (isInserting) {
      context.missing(_archivedMeta);
    }
    if (data.containsKey('has_pending_work')) {
      context.handle(
        _hasPendingWorkMeta,
        hasPendingWork.isAcceptableOrUnknown(
          data['has_pending_work']!,
          _hasPendingWorkMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasPendingWorkMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    } else if (isInserting) {
      context.missing(_metadataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredAgentConversation map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredAgentConversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      hasPendingWork: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_pending_work'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
    );
  }

  @override
  $AgentConversationsTable createAlias(String alias) {
    return $AgentConversationsTable(attachedDatabase, alias);
  }
}

class StoredAgentConversation extends DataClass
    implements Insertable<StoredAgentConversation> {
  final String id;
  final String title;
  final DateTime updatedAt;
  final bool archived;
  final bool hasPendingWork;
  final String metadata;
  const StoredAgentConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.archived,
    required this.hasPendingWork,
    required this.metadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['archived'] = Variable<bool>(archived);
    map['has_pending_work'] = Variable<bool>(hasPendingWork);
    map['metadata'] = Variable<String>(metadata);
    return map;
  }

  AgentConversationsCompanion toCompanion(bool nullToAbsent) {
    return AgentConversationsCompanion(
      id: Value(id),
      title: Value(title),
      updatedAt: Value(updatedAt),
      archived: Value(archived),
      hasPendingWork: Value(hasPendingWork),
      metadata: Value(metadata),
    );
  }

  factory StoredAgentConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredAgentConversation(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archived: serializer.fromJson<bool>(json['archived']),
      hasPendingWork: serializer.fromJson<bool>(json['hasPendingWork']),
      metadata: serializer.fromJson<String>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archived': serializer.toJson<bool>(archived),
      'hasPendingWork': serializer.toJson<bool>(hasPendingWork),
      'metadata': serializer.toJson<String>(metadata),
    };
  }

  StoredAgentConversation copyWith({
    String? id,
    String? title,
    DateTime? updatedAt,
    bool? archived,
    bool? hasPendingWork,
    String? metadata,
  }) => StoredAgentConversation(
    id: id ?? this.id,
    title: title ?? this.title,
    updatedAt: updatedAt ?? this.updatedAt,
    archived: archived ?? this.archived,
    hasPendingWork: hasPendingWork ?? this.hasPendingWork,
    metadata: metadata ?? this.metadata,
  );
  StoredAgentConversation copyWithCompanion(AgentConversationsCompanion data) {
    return StoredAgentConversation(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archived: data.archived.present ? data.archived.value : this.archived,
      hasPendingWork: data.hasPendingWork.present
          ? data.hasPendingWork.value
          : this.hasPendingWork,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredAgentConversation(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archived: $archived, ')
          ..write('hasPendingWork: $hasPendingWork, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, updatedAt, archived, hasPendingWork, metadata);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredAgentConversation &&
          other.id == this.id &&
          other.title == this.title &&
          other.updatedAt == this.updatedAt &&
          other.archived == this.archived &&
          other.hasPendingWork == this.hasPendingWork &&
          other.metadata == this.metadata);
}

class AgentConversationsCompanion
    extends UpdateCompanion<StoredAgentConversation> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> updatedAt;
  final Value<bool> archived;
  final Value<bool> hasPendingWork;
  final Value<String> metadata;
  final Value<int> rowid;
  const AgentConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archived = const Value.absent(),
    this.hasPendingWork = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentConversationsCompanion.insert({
    required String id,
    required String title,
    required DateTime updatedAt,
    required bool archived,
    required bool hasPendingWork,
    required String metadata,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       updatedAt = Value(updatedAt),
       archived = Value(archived),
       hasPendingWork = Value(hasPendingWork),
       metadata = Value(metadata);
  static Insertable<StoredAgentConversation> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<DateTime>? updatedAt,
    Expression<bool>? archived,
    Expression<bool>? hasPendingWork,
    Expression<String>? metadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archived != null) 'archived': archived,
      if (hasPendingWork != null) 'has_pending_work': hasPendingWork,
      if (metadata != null) 'metadata': metadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? updatedAt,
    Value<bool>? archived,
    Value<bool>? hasPendingWork,
    Value<String>? metadata,
    Value<int>? rowid,
  }) {
    return AgentConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
      hasPendingWork: hasPendingWork ?? this.hasPendingWork,
      metadata: metadata ?? this.metadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (hasPendingWork.present) {
      map['has_pending_work'] = Variable<bool>(hasPendingWork.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archived: $archived, ')
          ..write('hasPendingWork: $hasPendingWork, ')
          ..write('metadata: $metadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentItemsTable extends AgentItems
    with TableInfo<$AgentItemsTable, StoredAgentItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    collection,
    owner,
    id,
    position,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredAgentItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, owner, id};
  @override
  StoredAgentItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredAgentItem(
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $AgentItemsTable createAlias(String alias) {
    return $AgentItemsTable(attachedDatabase, alias);
  }
}

class StoredAgentItem extends DataClass implements Insertable<StoredAgentItem> {
  final String collection;
  final String owner;
  final String id;
  final int position;
  final String payload;
  const StoredAgentItem({
    required this.collection,
    required this.owner,
    required this.id,
    required this.position,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['owner'] = Variable<String>(owner);
    map['id'] = Variable<String>(id);
    map['position'] = Variable<int>(position);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  AgentItemsCompanion toCompanion(bool nullToAbsent) {
    return AgentItemsCompanion(
      collection: Value(collection),
      owner: Value(owner),
      id: Value(id),
      position: Value(position),
      payload: Value(payload),
    );
  }

  factory StoredAgentItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredAgentItem(
      collection: serializer.fromJson<String>(json['collection']),
      owner: serializer.fromJson<String>(json['owner']),
      id: serializer.fromJson<String>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'owner': serializer.toJson<String>(owner),
      'id': serializer.toJson<String>(id),
      'position': serializer.toJson<int>(position),
      'payload': serializer.toJson<String>(payload),
    };
  }

  StoredAgentItem copyWith({
    String? collection,
    String? owner,
    String? id,
    int? position,
    String? payload,
  }) => StoredAgentItem(
    collection: collection ?? this.collection,
    owner: owner ?? this.owner,
    id: id ?? this.id,
    position: position ?? this.position,
    payload: payload ?? this.payload,
  );
  StoredAgentItem copyWithCompanion(AgentItemsCompanion data) {
    return StoredAgentItem(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      owner: data.owner.present ? data.owner.value : this.owner,
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredAgentItem(')
          ..write('collection: $collection, ')
          ..write('owner: $owner, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, owner, id, position, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredAgentItem &&
          other.collection == this.collection &&
          other.owner == this.owner &&
          other.id == this.id &&
          other.position == this.position &&
          other.payload == this.payload);
}

class AgentItemsCompanion extends UpdateCompanion<StoredAgentItem> {
  final Value<String> collection;
  final Value<String> owner;
  final Value<String> id;
  final Value<int> position;
  final Value<String> payload;
  final Value<int> rowid;
  const AgentItemsCompanion({
    this.collection = const Value.absent(),
    this.owner = const Value.absent(),
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentItemsCompanion.insert({
    required String collection,
    required String owner,
    required String id,
    this.position = const Value.absent(),
    required String payload,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       owner = Value(owner),
       id = Value(id),
       payload = Value(payload);
  static Insertable<StoredAgentItem> custom({
    Expression<String>? collection,
    Expression<String>? owner,
    Expression<String>? id,
    Expression<int>? position,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (owner != null) 'owner': owner,
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentItemsCompanion copyWith({
    Value<String>? collection,
    Value<String>? owner,
    Value<String>? id,
    Value<int>? position,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return AgentItemsCompanion(
      collection: collection ?? this.collection,
      owner: owner ?? this.owner,
      id: id ?? this.id,
      position: position ?? this.position,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentItemsCompanion(')
          ..write('collection: $collection, ')
          ..write('owner: $owner, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentMetadataTable extends AgentMetadata
    with TableInfo<$AgentMetadataTable, StoredAgentMetadata> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentMetadataTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'agent_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredAgentMetadata> instance, {
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
  StoredAgentMetadata map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredAgentMetadata(
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
  $AgentMetadataTable createAlias(String alias) {
    return $AgentMetadataTable(attachedDatabase, alias);
  }
}

class StoredAgentMetadata extends DataClass
    implements Insertable<StoredAgentMetadata> {
  final String key;
  final String value;
  const StoredAgentMetadata({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AgentMetadataCompanion toCompanion(bool nullToAbsent) {
    return AgentMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory StoredAgentMetadata.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredAgentMetadata(
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

  StoredAgentMetadata copyWith({String? key, String? value}) =>
      StoredAgentMetadata(key: key ?? this.key, value: value ?? this.value);
  StoredAgentMetadata copyWithCompanion(AgentMetadataCompanion data) {
    return StoredAgentMetadata(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredAgentMetadata(')
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
      (other is StoredAgentMetadata &&
          other.key == this.key &&
          other.value == this.value);
}

class AgentMetadataCompanion extends UpdateCompanion<StoredAgentMetadata> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AgentMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<StoredAgentMetadata> custom({
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

  AgentMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AgentMetadataCompanion(
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
    return (StringBuffer('AgentMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AgentDatabase extends GeneratedDatabase {
  _$AgentDatabase(QueryExecutor e) : super(e);
  $AgentDatabaseManager get managers => $AgentDatabaseManager(this);
  late final $AgentConversationsTable agentConversations =
      $AgentConversationsTable(this);
  late final $AgentItemsTable agentItems = $AgentItemsTable(this);
  late final $AgentMetadataTable agentMetadata = $AgentMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    agentConversations,
    agentItems,
    agentMetadata,
  ];
}

typedef $$AgentConversationsTableCreateCompanionBuilder =
    AgentConversationsCompanion Function({
      required String id,
      required String title,
      required DateTime updatedAt,
      required bool archived,
      required bool hasPendingWork,
      required String metadata,
      Value<int> rowid,
    });
typedef $$AgentConversationsTableUpdateCompanionBuilder =
    AgentConversationsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<DateTime> updatedAt,
      Value<bool> archived,
      Value<bool> hasPendingWork,
      Value<String> metadata,
      Value<int> rowid,
    });

class $$AgentConversationsTableFilterComposer
    extends Composer<_$AgentDatabase, $AgentConversationsTable> {
  $$AgentConversationsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasPendingWork => $composableBuilder(
    column: $table.hasPendingWork,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgentConversationsTableOrderingComposer
    extends Composer<_$AgentDatabase, $AgentConversationsTable> {
  $$AgentConversationsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasPendingWork => $composableBuilder(
    column: $table.hasPendingWork,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentConversationsTableAnnotationComposer
    extends Composer<_$AgentDatabase, $AgentConversationsTable> {
  $$AgentConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<bool> get hasPendingWork => $composableBuilder(
    column: $table.hasPendingWork,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
}

class $$AgentConversationsTableTableManager
    extends
        RootTableManager<
          _$AgentDatabase,
          $AgentConversationsTable,
          StoredAgentConversation,
          $$AgentConversationsTableFilterComposer,
          $$AgentConversationsTableOrderingComposer,
          $$AgentConversationsTableAnnotationComposer,
          $$AgentConversationsTableCreateCompanionBuilder,
          $$AgentConversationsTableUpdateCompanionBuilder,
          (
            StoredAgentConversation,
            BaseReferences<
              _$AgentDatabase,
              $AgentConversationsTable,
              StoredAgentConversation
            >,
          ),
          StoredAgentConversation,
          PrefetchHooks Function()
        > {
  $$AgentConversationsTableTableManager(
    _$AgentDatabase db,
    $AgentConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<bool> hasPendingWork = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentConversationsCompanion(
                id: id,
                title: title,
                updatedAt: updatedAt,
                archived: archived,
                hasPendingWork: hasPendingWork,
                metadata: metadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required DateTime updatedAt,
                required bool archived,
                required bool hasPendingWork,
                required String metadata,
                Value<int> rowid = const Value.absent(),
              }) => AgentConversationsCompanion.insert(
                id: id,
                title: title,
                updatedAt: updatedAt,
                archived: archived,
                hasPendingWork: hasPendingWork,
                metadata: metadata,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $AgentConversationsTable,
                    StoredAgentConversation
                  >(table),
                  BaseReferences<
                    _$AgentDatabase,
                    $AgentConversationsTable,
                    StoredAgentConversation
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AgentConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AgentDatabase,
      $AgentConversationsTable,
      StoredAgentConversation,
      $$AgentConversationsTableFilterComposer,
      $$AgentConversationsTableOrderingComposer,
      $$AgentConversationsTableAnnotationComposer,
      $$AgentConversationsTableCreateCompanionBuilder,
      $$AgentConversationsTableUpdateCompanionBuilder,
      (
        StoredAgentConversation,
        BaseReferences<
          _$AgentDatabase,
          $AgentConversationsTable,
          StoredAgentConversation
        >,
      ),
      StoredAgentConversation,
      PrefetchHooks Function()
    >;
typedef $$AgentItemsTableCreateCompanionBuilder = AgentItemsCompanion Function({
  required String collection,
  required String owner,
  required String id,
  Value<int> position,
  required String payload,
  Value<int> rowid,
});
typedef $$AgentItemsTableUpdateCompanionBuilder = AgentItemsCompanion Function({
  Value<String> collection,
  Value<String> owner,
  Value<String> id,
  Value<int> position,
  Value<String> payload,
  Value<int> rowid,
});

class $$AgentItemsTableFilterComposer
    extends Composer<_$AgentDatabase, $AgentItemsTable> {
  $$AgentItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgentItemsTableOrderingComposer
    extends Composer<_$AgentDatabase, $AgentItemsTable> {
  $$AgentItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentItemsTableAnnotationComposer
    extends Composer<_$AgentDatabase, $AgentItemsTable> {
  $$AgentItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$AgentItemsTableTableManager
    extends
        RootTableManager<
          _$AgentDatabase,
          $AgentItemsTable,
          StoredAgentItem,
          $$AgentItemsTableFilterComposer,
          $$AgentItemsTableOrderingComposer,
          $$AgentItemsTableAnnotationComposer,
          $$AgentItemsTableCreateCompanionBuilder,
          $$AgentItemsTableUpdateCompanionBuilder,
          (
            StoredAgentItem,
            BaseReferences<_$AgentDatabase, $AgentItemsTable, StoredAgentItem>,
          ),
          StoredAgentItem,
          PrefetchHooks Function()
        > {
  $$AgentItemsTableTableManager(_$AgentDatabase db, $AgentItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collection = const Value.absent(),
                Value<String> owner = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentItemsCompanion(
                collection: collection,
                owner: owner,
                id: id,
                position: position,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collection,
                required String owner,
                required String id,
                Value<int> position = const Value.absent(),
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => AgentItemsCompanion.insert(
                collection: collection,
                owner: owner,
                id: id,
                position: position,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AgentItemsTable, StoredAgentItem>(table),
                  BaseReferences<
                    _$AgentDatabase,
                    $AgentItemsTable,
                    StoredAgentItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AgentItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AgentDatabase,
      $AgentItemsTable,
      StoredAgentItem,
      $$AgentItemsTableFilterComposer,
      $$AgentItemsTableOrderingComposer,
      $$AgentItemsTableAnnotationComposer,
      $$AgentItemsTableCreateCompanionBuilder,
      $$AgentItemsTableUpdateCompanionBuilder,
      (
        StoredAgentItem,
        BaseReferences<_$AgentDatabase, $AgentItemsTable, StoredAgentItem>,
      ),
      StoredAgentItem,
      PrefetchHooks Function()
    >;
typedef $$AgentMetadataTableCreateCompanionBuilder =
    AgentMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AgentMetadataTableUpdateCompanionBuilder =
    AgentMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AgentMetadataTableFilterComposer
    extends Composer<_$AgentDatabase, $AgentMetadataTable> {
  $$AgentMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgentMetadataTableOrderingComposer
    extends Composer<_$AgentDatabase, $AgentMetadataTable> {
  $$AgentMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentMetadataTableAnnotationComposer
    extends Composer<_$AgentDatabase, $AgentMetadataTable> {
  $$AgentMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AgentMetadataTableTableManager
    extends
        RootTableManager<
          _$AgentDatabase,
          $AgentMetadataTable,
          StoredAgentMetadata,
          $$AgentMetadataTableFilterComposer,
          $$AgentMetadataTableOrderingComposer,
          $$AgentMetadataTableAnnotationComposer,
          $$AgentMetadataTableCreateCompanionBuilder,
          $$AgentMetadataTableUpdateCompanionBuilder,
          (
            StoredAgentMetadata,
            BaseReferences<
              _$AgentDatabase,
              $AgentMetadataTable,
              StoredAgentMetadata
            >,
          ),
          StoredAgentMetadata,
          PrefetchHooks Function()
        > {
  $$AgentMetadataTableTableManager(
    _$AgentDatabase db,
    $AgentMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AgentMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AgentMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AgentMetadataTable, StoredAgentMetadata>(table),
                  BaseReferences<
                    _$AgentDatabase,
                    $AgentMetadataTable,
                    StoredAgentMetadata
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AgentMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AgentDatabase,
      $AgentMetadataTable,
      StoredAgentMetadata,
      $$AgentMetadataTableFilterComposer,
      $$AgentMetadataTableOrderingComposer,
      $$AgentMetadataTableAnnotationComposer,
      $$AgentMetadataTableCreateCompanionBuilder,
      $$AgentMetadataTableUpdateCompanionBuilder,
      (
        StoredAgentMetadata,
        BaseReferences<
          _$AgentDatabase,
          $AgentMetadataTable,
          StoredAgentMetadata
        >,
      ),
      StoredAgentMetadata,
      PrefetchHooks Function()
    >;

class $AgentDatabaseManager {
  final _$AgentDatabase _db;
  $AgentDatabaseManager(this._db);
  $$AgentConversationsTableTableManager get agentConversations =>
      $$AgentConversationsTableTableManager(_db, _db.agentConversations);
  $$AgentItemsTableTableManager get agentItems =>
      $$AgentItemsTableTableManager(_db, _db.agentItems);
  $$AgentMetadataTableTableManager get agentMetadata =>
      $$AgentMetadataTableTableManager(_db, _db.agentMetadata);
}
