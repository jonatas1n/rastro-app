import 'package:uuid/uuid.dart';

enum TransactionCategory {
  alimentacao, transporte, saude, compras, lazer, mercado, outros,
}

extension TransactionCategoryX on TransactionCategory {
  String get label => switch (this) {
    TransactionCategory.alimentacao => 'Alimentação',
    TransactionCategory.transporte  => 'Transporte',
    TransactionCategory.saude       => 'Saúde',
    TransactionCategory.compras     => 'Compras',
    TransactionCategory.lazer       => 'Lazer',
    TransactionCategory.mercado     => 'Mercado',
    TransactionCategory.outros      => 'Outros',
  };

  String get emoji => switch (this) {
    TransactionCategory.alimentacao => '🍽️',
    TransactionCategory.transporte  => '🚗',
    TransactionCategory.saude       => '💊',
    TransactionCategory.compras     => '🛍️',
    TransactionCategory.lazer       => '🎬',
    TransactionCategory.mercado     => '🛒',
    TransactionCategory.outros      => '💳',
  };

  String get dbValue => name;

  static TransactionCategory fromDb(String v) =>
      TransactionCategory.values.firstWhere((e) => e.name == v,
          orElse: () => TransactionCategory.outros);
}

const _uuid = Uuid();

class Transaction {
  final int?    id;
  final String  localId;     // UUID gerado no device — chave de sincronização
  final int?    serverId;    // ID retornado pelo backend após sync
  final String  place;
  final double  amount;
  final TransactionCategory category;
  final DateTime timestamp;
  final bool    isEssential;
  final String? rawNotification;
  final bool    synced;      // false = pendente na fila de sync

  Transaction({
    this.id,
    String? localId,
    this.serverId,
    required this.place,
    required this.amount,
    required this.category,
    required this.timestamp,
    this.isEssential     = true,
    this.rawNotification,
    this.synced          = false,
  }) : localId = localId ?? _uuid.v4();

  Transaction copyWith({
    String?               place,
    double?               amount,
    DateTime?             timestamp,
    bool?                 isEssential,
    TransactionCategory?  category,
    bool?                 synced,
    int?                  serverId,
  }) =>
      Transaction(
        id:              id,
        localId:         localId,
        serverId:        serverId    ?? this.serverId,
        place:           place       ?? this.place,
        amount:          amount      ?? this.amount,
        category:        category    ?? this.category,
        timestamp:       timestamp   ?? this.timestamp,
        isEssential:     isEssential ?? this.isEssential,
        rawNotification: rawNotification,
        synced:          synced      ?? this.synced,
      );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'local_id':          localId,
    'server_id':         serverId,
    'place':             place,
    'amount':            amount,
    'category':          category.dbValue,
    'timestamp':         timestamp.millisecondsSinceEpoch,
    'is_essential':      isEssential ? 1 : 0,
    'raw_notification':  rawNotification,
    'synced':            synced ? 1 : 0,
  };

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
    id:              m['id'] as int?,
    localId:         m['local_id'] as String,
    serverId:        m['server_id'] as int?,
    place:           m['place'] as String,
    amount:          (m['amount'] as num).toDouble(),
    category:        TransactionCategoryX.fromDb(m['category'] as String),
    timestamp:       DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
    isEssential:     (m['is_essential'] as int) == 1,
    rawNotification: m['raw_notification'] as String?,
    synced:          (m['synced'] as int? ?? 0) == 1,
  );
}
