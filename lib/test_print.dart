import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class TestPrinterPage extends StatefulWidget {
  const TestPrinterPage({super.key});

  @override
  State<TestPrinterPage> createState() => _TestPrinterPageState();
}

class _TestPrinterPageState extends State<TestPrinterPage> {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  bool connected = false;

  @override
  void initState() {
    super.initState();
    initBluetooth();
  }

  void initBluetooth() async {
    try {
      final List<BluetoothDevice> pairedDevices = await bluetooth
          .getBondedDevices();
      setState(() {
        devices = pairedDevices;
      });

      bluetooth.isConnected.then((isConnected) {
        setState(() {
          connected = isConnected ?? false;
        });
      });
    } catch (e) {
      debugPrint("Error initBluetooth: $e");
    }
  }

  Future<void> connect() async {
    if (selectedDevice == null) return;
    try {
      await bluetooth.connect(selectedDevice!);
      setState(() => connected = true);
    } catch (e) {
      debugPrint("Error connect: $e");
      setState(() => connected = false);
    }
  }

  Future<void> disconnect() async {
    try {
      await bluetooth.disconnect();
      setState(() => connected = false);
    } catch (e) {
      debugPrint("Error disconnect: $e");
    }
  }

  Future<void> printReceipt() async {
    if (!connected) return;

    try {
      bluetooth.printNewLine();
      bluetooth.printCustom("==== TEST STRUK ====", 1, 1);
      bluetooth.printCustom("Hello World", 1, 0);
      bluetooth.printCustom("Minyak Goreng", 1, 0);
      bluetooth.printCustom("Harga: 10.000", 1, 0);
      bluetooth.printCustom("===================", 1, 1);
      bluetooth.printNewLine();

      bluetooth.printLeftRight("Subtotal", "9.090,90", 1);
      bluetooth.printLeftRight("PPN", "909,10", 1);
      bluetooth.printLeftRight("TOTAL", "10.000", 2);
      bluetooth.printLeftRight("Bayar", "10.000", 1);
      bluetooth.printNewLine();

      bluetooth.printCustom("::Terima Kasih::", 1, 1);
      bluetooth.printCustom("::Barang tdk dpt ditukar::", 1, 1);
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } catch (e) {
      debugPrint("Error printReceipt: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bluetooth Printer")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<BluetoothDevice>(
              hint: const Text("Pilih Printer"),
              value: selectedDevice,
              onChanged: (device) => setState(() => selectedDevice = device),
              items: devices
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.name ?? d.address ?? ""),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: connect,
                  child: const Text("Hubungkan"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: disconnect,
                  child: const Text("Putuskan"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: connected ? printReceipt : null,
              child: const Text("🖨️ Cetak Nota"),
            ),
          ],
        ),
      ),
    );
  }
}
