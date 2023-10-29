
import 'package:abdelmohsen_ahmed_task/sqf.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbHelper = SqlDataBase.instance;

  final database = await dbHelper.database;
  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final Database database;

  const MyApp({required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stocktaking App',
      home: StocktakingScreen(database: database),
    );
  }
}

class StocktakingScreen extends StatefulWidget {
  final Database database;

  const StocktakingScreen({required this.database});

  @override
  _StocktakingScreenState createState() => _StocktakingScreenState();
}

class _StocktakingScreenState extends State<StocktakingScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  String? _currentDocumentNumber;
  String? _itemName;
  String? _itemPrice;
  String? _itemQuantity;
  List<Map<String, dynamic>> _documentItems = [];

  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentNumber() async {
    final String lastDocumentNumber = await _getLastDocumentNumber();
    setState(() {
      _currentDocumentNumber = (lastDocumentNumber.isNotEmpty) ? '${int.parse(lastDocumentNumber) + 1}' : '1';
    });
  }

  Future<String> _getLastDocumentNumber() async {
    final Database database = widget.database;
    final List<Map<String, dynamic>> records = await database.query(
      SqlDataBase.tableStockRecords,
      columns: [SqlDataBase.columnRecordDocNumber],
      orderBy: '${SqlDataBase.columnRecordDocNumber} DESC',
      limit: 1,
    );
    if (records.isNotEmpty) {
      return records.first[SqlDataBase.columnRecordDocNumber].toString();
    } else {
      return '';
    }
  }

  Future<Map<String, dynamic>> _getItemByBarcode(String barcode) async {
    final Database database = widget.database;
    final List<Map<String, dynamic>> items = await database.query(
      SqlDataBase.tableItems,
      where: '${SqlDataBase.columnItemBarcode} = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (items.isNotEmpty) {
      return items.first;
    } else {
      return {};
    }
  }

  Future<void> _addItem() async {
    final String barcode = _barcodeController.text.trim();
    final String quantity = _quantityController.text.trim();
    final Map<String, dynamic> item = await _getItemByBarcode(barcode);

    if (item.isNotEmpty && !_isItemInDocument(item[SqlDataBase.columnItemId])) {
      item['quantity'] = int.parse(quantity);
      _documentItems.add(item);
      _resetFields();
      setState(() {});
    } else {
      _showErrorSnackBar('Item not found or already in document');
    }
  }

  bool _isItemInDocument(String itemId) {
    return _documentItems.any((item) => item[SqlDataBase.columnItemId] == itemId);
  }

  void _resetFields() {
    _barcodeController.clear();
    _quantityController.text = '1';
    _itemName = null;
    _itemPrice = null;
    _itemQuantity = null;
  }

  Future<void> _saveDocument() async {
    if (_currentDocumentNumber != null && _documentItems.isNotEmpty) {
      final DateTime now = DateTime.now();
      final String timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final Database database = widget.database;
      final Batch batch = database.batch();
      final String documentNumber = _currentDocumentNumber!;
      final List<Map<String, dynamic>> updatedItems = [];

      for (final Map<String, dynamic> item in _documentItems) {
        final int recordQuantity = item['quantity'];
        final Map<String, dynamic> updatedItem = Map.from(item);

        updatedItem[SqlDataBase.columnItemQuantity] += recordQuantity;

        final Map<String, dynamic> stockRecord = {
          SqlDataBase.columnRecordDocNumber: documentNumber,
          SqlDataBase.columnRecordTime: timestamp,
          SqlDataBase.columnItemIdFK: item[SqlDataBase.columnItemId],
          SqlDataBase.columnRecordQuantity: recordQuantity,
        };

        batch.insert(SqlDataBase.tableStockRecords, stockRecord);
        updatedItems.add(updatedItem);
      }

      for (final Map<String, dynamic> updatedItem in updatedItems) {
        final String itemId = updatedItem[SqlDataBase.columnItemId];
        final int itemQuantity = updatedItem[SqlDataBase.columnItemQuantity];

        batch.update(
          SqlDataBase.tableItems,
          {SqlDataBase.columnItemQuantity: itemQuantity},
          where: '${SqlDataBase.columnItemId} = ?',
          whereArgs: [itemId],
        );
      }

      await batch.commit();

      _documentItems.clear();
      _currentDocumentNumber = null;
      _resetFields();
      setState(() {});

      _showSnackBar('Document saved successfully');
    } else {
      _showErrorSnackBar('No items found in the document');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showErrorSnackBar(String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void initState() {
    _loadDocumentNumber();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stocktaking App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Document Number: $_currentDocumentNumber',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode',
              ),
            ),
            SizedBox(height: 8.0),
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _addItem,
              child: Text('Add'),
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                itemCount: _documentItems.length,
                itemBuilder: (context, index) {
                  final item = _documentItems[index];
                  return ListTile(
                    title: Text(item[SqlDataBase.columnItemName]),
                    subtitle: Text('Quantity: ${item['quantity']}'),
                  );
                },
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _saveDocument,
              child: Text('Save'),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode',
              ),
            ),
            SizedBox(height: 8.0),
            Text('Item Name: $_itemName'),
            Text('Price: $_itemPrice'),
            Text('Quantity: $_itemQuantity'),
          ],
        ),
      ),
    );
  }
}