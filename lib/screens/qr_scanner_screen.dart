import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/firestore_service.dart';
import '../models/timetable.dart';
import '../models/module.dart';
import '../models/timetable_entry.dart';
import '../services/pdf_parser_service.dart'; // For ParsedData structure
import 'shared_schedule_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to scan QR codes')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleScan(String? shareId) async {
    if (shareId == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Fetch data
      final data = await FirestoreService().fetchSharedTimetable(shareId);
      
      debugPrint('QR_DEBUG: Raw Data keys: ${data.keys}');
      debugPrint('QR_DEBUG: Modules count raw: ${(data['modules'] as List).length}');
      debugPrint('QR_DEBUG: Entries count raw: ${(data['entries'] as List).length}');

      // Parse into models
      final timetableMap = data['timetable'] as Map<String, dynamic>;
      // We create a NEW ID for the imported timetable to avoid conflicts
      final timetable = Timetable.fromMap(timetableMap, '').copyWith(
        name: '${timetableMap['name']} (Imported)',
        isCurrent: true,
      );

      final modules = (data['modules'] as List<dynamic>)
          .map((m) {
            try {
              return Module.fromMap(m as Map<String, dynamic>);
            } catch (e) {
               debugPrint('QR_DEBUG: Error parsing module: $e');
               return null;
            }
          })
          .whereType<Module>()
          .toList();

      final entries = (data['entries'] as List<dynamic>)
          .map((e) {
            try {
              return TimeTableEntry.fromMap(e as Map<String, dynamic>, '');
            } catch (e) {
               debugPrint('QR_DEBUG: Error parsing entry: $e');
               return null;
            }
          })
          .whereType<TimeTableEntry>()
          .toList();
          
      debugPrint('QR_DEBUG: Parsed Modules: ${modules.length}');
      debugPrint('QR_DEBUG: Parsed Entries: ${entries.length}');

      if (mounted) {
        // Navigate to ImportPreview (we need to adapt ImportPreviewScreen to accept pre-parsed data)
        // Or simpler: Just confirmation dialog since we trust the data source format?
        // Let's reuse ImportPreviewScreen but we need to modify it to accept data.
        // For now, let's create a custom confirmation dialog here as a simpler first step,
        // or Refactor ImportPreviewScreen.
        
        // Actually, ParsedData is what ImportPreviewScreen expects? No, it expects nothing and picks file.
        // I should probably make ImportPreviewScreen adaptable.
        // But to save time, I will pass data to a new mode of ImportPreviewScreen or just a new screen.
        // Let's try to pass it to ImportPreviewScreen.
        
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SharedScheduleScreen(
              importedTimetable: timetable,
              modules: modules,
              classes: entries,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing: $e')),
        );
        // Resume scanning after error? 
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleScan(barcode.rawValue);
                  break; // Only handle first
                }
              }
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
          // Helper overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
