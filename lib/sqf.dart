import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SqlDataBase {
   static final _databaseName = 'stocktaking.db';
  static final _databaseVersion = 1;

  static final tableItems = 'items';
  static final columnItemId = 'item_id';
  static final columnItemName = 'item_name';
  static final columnItemBarcode = 'item_barcode';
  static final columnItemPrice = 'item_price';
  static final columnItemQuantity = 'item_quantity';

  static final tableStockRecords = 'stock_records';
  static final columnRecordDocNumber = 'record_doc_number';
  static final columnRecordTime = 'record_time';
  static final columnItemIdFK = 'item_id_fk';
  static final columnRecordQuantity = 'record_quantity';

  SqlDataBase._privateConstructor();
  static final SqlDataBase instance = SqlDataBase._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), '$_databaseName');
    return await openDatabase(path, version: _databaseVersion, onCreate: _createTables);
  }

  void _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableItems (
        $columnItemId TEXT PRIMARY KEY,
        $columnItemName TEXT,
        $columnItemBarcode TEXT UNIQUE,
        $columnItemPrice REAL,
        $columnItemQuantity INTEGER
      )
      ''');

    await db.execute('''
      CREATE TABLE $tableStockRecords (
        $columnRecordDocNumber INTEGER,
        $columnRecordTime TEXT,
        $columnItemIdFK TEXT,
        $columnRecordQuantity INTEGER,
        FOREIGN KEY ($columnItemIdFK) REFERENCES $tableItems ($columnItemId),
        PRIMARY KEY ($columnRecordDocNumber, $columnRecordTime, $columnItemIdFK)
      )
      ''');
    print("__________________Function OnCreate Working_________________");
  }

  readData(String sql) async {
    Database? myDataBase = await _database;
    List<Map> res = await myDataBase!.rawQuery(sql);
    return res;
  }

  deleteData(String sql) async {
    Database? myDataBase = await _database;
    int res = await myDataBase!.rawDelete(sql);
    return res;
  }

  insertData(String sql) async {
    Database? myDataBase = await _database;
    int res = await myDataBase!.rawInsert(sql);
    return res;
  }

  updateData(String sql) async {
    Database? myDataBase = await _database;
    int res = await myDataBase!.rawUpdate(sql);
    return res;
  }
}


