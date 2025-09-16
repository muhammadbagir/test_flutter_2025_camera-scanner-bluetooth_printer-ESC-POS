import 'package:flutter/material.dart';
import 'camera_page.dart';
import 'camera_scanner.dart';
import 'test_print.dart'; // file test_print.dart

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home Page")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Buka Kamera"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraPage()),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Buka Camera Scanner"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScannerPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Tombol baru untuk test printer
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text("Test Printer"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TestPrinterPage(), // ✅ sesuai
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
