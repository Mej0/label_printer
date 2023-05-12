import 'dart:collection';
import 'dart:io';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:zebrautility/ZebraPrinter.dart';
import 'package:zebrautility/zebrautility.dart';

class Product {
  const Product({
    required this.productName,
    required this.price,
    required this.supplier,
  });

  final String productName;
  final double price;
  final String supplier;
}

class ProductInfoDisplay extends StatelessWidget {
  const ProductInfoDisplay({required this.barcode, required this.productName, required this.price, required this.supplier, super.key});

  final String barcode;
  final String productName;
  final double price;
  final String supplier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('条码: $barcode'), Text('产品: $productName'), Text('价格: ${price.toStringAsFixed(2)}'), Text('供应商: $supplier')],
    );
  }
}

class SubmitButtons extends StatelessWidget {
  const SubmitButtons({required this.onPressed, required this.onCheck, required this.autoPrint, super.key});

  final VoidCallback onPressed;
  final ValueChanged<bool> onCheck;
  final bool autoPrint;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Switch(value: autoPrint, onChanged: onCheck),
        const SizedBox(
          width: 8,
        ),
        ElevatedButton(
          onPressed: onPressed,
          child: const Text('打印'),
        ),
      ],
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyApp();
}

class _MyApp extends State<MyApp> {
  bool autoPrint = false;
  late HashMap<String, Product> products;
  MapEntry<String, Product>? currentProduct;
  late FocusNode myFocusNode;
  final macAddress = '48:A4:93:D5:20:25';
  String status = 'Disconnected';
  late ZebraPrinter zebraPrinter;
  late TextEditingController controller;
  String barcode = '';

  void toggleAutoPrint(value) {
    setState(() {
      autoPrint = value;
    });
  }

  // void setCurrentProduct(value) {
  //   setState(() {
  //     currentProduct = value;
  //   });
  // }

  void setStatus(value) {
    setState(() {
      status = value;
    });
  }

  void setBarcode(value) {
    setState(() {
      barcode = value;
      var p = products[value];
      currentProduct = p != null ? MapEntry<String, Product>(value, p) : null;
      if (autoPrint) {
        tryPrint();
      }
    });
  }

  void tryConnect() async {
    zebraPrinter = await Zebrautility.getPrinterInstance(
        onPrinterFound: (name, ipAddress, isWifi) => debugPrint("PrinterFound :" + name + " " + ipAddress),
        onPrinterDiscoveryDone: (errorCode, errorText) => debugPrint("Discovery Done"),
        onChangePrinterStatus: (status, color) {
          debugPrint("change printer status: " + status);
          setStatus(status);
        },
        onPermissionDenied: () => debugPrint("Permission Deny."));
    zebraPrinter.connectToPrinter(macAddress);
  }

  void tryPrint() {
    if (currentProduct?.key != null) {
      zebraPrinter.print('''^XA
^CFD,18
^FO0,20^FD${currentProduct!.value.productName.length > 30 ? currentProduct!.value.productName.substring(0, 30) : currentProduct!.value.productName}^FS
^FO0,50^FD${currentProduct!.value.productName.length > 30 ? currentProduct!.value.productName.substring(30) : ''}^FS
^FO0,95^BC,50^FD${currentProduct!.key}^FS
^FO0,210^FD${currentProduct!.value.supplier}^FS
^FO${currentProduct!.value.price >= 10 ? 185 : 220},180^AVN^FH_^FD_15 ${currentProduct!.value.price.toStringAsFixed(2)}^FS
^XZ''');
    }
  }

  void startScan() async {
    String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode('#ff6666', '退出', false, ScanMode.BARCODE);
    if (barcode != barcodeScanRes) {
      setBarcode(barcodeScanRes);
    }
  }

  Future<String> get _localPath async {
    final directory = await getExternalStorageDirectory();

    return directory!.path;
  }

  Future<Map<String, Product>> fetchProducts() async {
    final directory = await _localPath;
    final file = File('$directory/shop_list.xlsx');
    var excel = Excel.decodeBytes(file.readAsBytesSync());
    Map<String, Product> map = {};

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table];
      if (sheet != null) {
        for (var i = 1; i < sheet.maxRows; i++) {
          map[sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value ?? 'barcode$i'] = Product(
              productName: sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value ?? '',
              price: double.parse(sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: i)).value.toString()),
              supplier: sheet.cell(CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: i)).value ?? '');
        }
      }
    }
    return map;
  }

  @override
  void initState() {
    fetchProducts().then((value) => products = HashMap.from(value));
    tryConnect();
    myFocusNode = FocusNode();
    controller = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        status == "Disconnected"
            ? ElevatedButton(
                onPressed: () {
                  zebraPrinter.connectToPrinter(macAddress);
                },
                child: const Text("连接"))
            : const SizedBox(
                height: 0,
              ),
        const SizedBox(
          height: 144,
        ),
        ProductInfoDisplay(
            barcode: currentProduct?.key ?? "",
            productName: currentProduct?.value.productName ?? "",
            price: currentProduct?.value.price ?? 0,
            supplier: currentProduct?.value.supplier ?? ""),
        const SizedBox(
          height: 24,
        ),
        SubmitButtons(
          onPressed: () {
            tryPrint();
          },
          onCheck: toggleAutoPrint,
          autoPrint: autoPrint,
        ),
        const SizedBox(
          height: 144,
        ),
        ElevatedButton(
          onPressed: startScan,
          style: const ButtonStyle(minimumSize: MaterialStatePropertyAll(Size.fromHeight(50))),
          child: const Text("扫描"),
        ),
      ],
    );
  }
}

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: MyApp(),
            )),
      ),
    ),
  );
}
