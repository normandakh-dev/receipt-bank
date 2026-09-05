import 'package:drift/drift.dart';

class Categories extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get name => text().withLength(min: 1, max: 80).unique()();
  TextColumn get iconCode => text().withLength(min: 1, max: 64)();
  IntColumn get colorValue => integer().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Receipts extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get merchantName => text().withLength(min: 1, max: 200)();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.restrict)();
  IntColumn get subtotalCents =>
      integer().named('subtotal').withDefault(const Constant(0))();
  IntColumn get taxCents =>
      integer().named('tax').withDefault(const Constant(0))();
  IntColumn get tipCents =>
      integer().named('tip').withDefault(const Constant(0))();
  IntColumn get totalCents => integer().named('total')();
  TextColumn get currencyCode =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('CAD'))();
  TextColumn get paymentMethod =>
      text().withLength(min: 1, max: 80).nullable()();
  TextColumn get cardLastFour => text().withLength(min: 4, max: 4).nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get purpose => text().withLength(min: 1, max: 160).nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get rawOcrText => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get warrantyExpirationDate => dateTime().nullable()();
  DateTimeColumn get returnDeadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReceiptItems extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get receiptId =>
      text().references(Receipts, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 240)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get unitPriceCents => integer().named('unit_price')();
  IntColumn get totalPriceCents => integer().named('total_price')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get name => text().withLength(min: 1, max: 80).unique()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReceiptTags extends Table {
  TextColumn get receiptId =>
      text().references(Receipts, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {receiptId, tagId};
}

class AppSettings extends Table {
  TextColumn get key => text().withLength(min: 1, max: 120)();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
