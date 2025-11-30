import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pdf_parser_service.dart';
import '../models/timetable_entry.dart';
import '../providers/timetable_provider.dart';

class ImportPreviewScreen extends StatefulWidget {
  const ImportPreviewScreen({super.key});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  final _parserService = PdfParserService();
  List<TimeTableEntry> _parsedEntries = [];
  bool _isLoading = false;
  final _apiKeyController = TextEditingController();

  Future<void> _pickAndParse() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Google Gemini API Key')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final entries = await _parserService.pickAndParsePdf(_apiKeyController.text);
      if (mounted) {
        setState(() {
          _parsedEntries = entries;
        });
        if (entries.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No entries found in PDF')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveEntries() {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    for (var entry in _parsedEntries) {
      provider.addEntry(entry);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${_parsedEntries.length} entries')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Timetable (AI Powered)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text('Enter Google Gemini API Key', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(),
                    hintText: 'AIzaSy...',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: _pickAndParse,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select PDF & Parse with AI'),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Note: The PDF will be sent to Google Gemini for processing.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _parsedEntries.length,
              itemBuilder: (context, index) {
                final entry = _parsedEntries[index];
                return ListTile(
                  title: Text(entry.subjectName),
                  subtitle: Text('${entry.type.name} - ${entry.dayOfWeek} ${entry.startTime.format(context)}'),
                );
              },
            ),
          ),
          if (_parsedEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _saveEntries,
                child: const Text('Save All Entries'),
              ),
            ),
        ],
      ),
    );
  }
}
