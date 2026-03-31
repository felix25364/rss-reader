import 'package:drift/drift.dart';

part 'database.g.dart';

/// Categories table schema.
/// This acts as the user's interest profile.
class Categories extends Table {
  TextColumn get name => text()();
  RealColumn get globalWeight => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {name};
}

/// Articles table schema.
class Articles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get link => text()();
  DateTimeColumn get pubDate => dateTime()();
  TextColumn get category => text().nullable().references(Categories, #name)();
  TextColumn get content => text()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  RealColumn get relevanceScore => real().withDefault(const Constant(0.0))();
}

/// Main application database.
@DriftDatabase(tables: [Articles, Categories])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}
