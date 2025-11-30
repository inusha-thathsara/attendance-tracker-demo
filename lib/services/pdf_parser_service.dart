import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/timetable_entry.dart';
import '../models/enums.dart';

class PdfParserService {
  Future<List<TimeTableEntry>> pickAndParsePdf(String apiKey) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      
      return _parseWithGemini(text, apiKey);
    }
    return [];
  }

  Future<List<TimeTableEntry>> _parseWithGemini(String text, String apiKey) async {
    try {
      final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
      final prompt = '''
      Extract the university timetable from the following text and return it as a JSON list.
      The text is extracted from a PDF and might be unstructured.
      
      Each item in the list should have:
      - "subjectName": String (Name of the module/subject)
      - "type": String (One of: "lecture", "tutorial", "lab")
      - "dayOfWeek": Integer (1 for Monday, 2 for Tuesday, ..., 7 for Sunday)
      - "startTime": String (Format "HH:MM", 24-hour format)
      - "endTime": String (Format "HH:MM", 24-hour format)

      Rules:
      - If the type is not clear, default to "lecture".
      - If "Lab" or "Practical" is mentioned, type is "lab".
      - If "Tutorial" or "T" is mentioned, type is "tutorial".
      - Ignore headers, footers, and irrelevant text.
      - Return ONLY the JSON string, no markdown formatting.
      
      Text:
      $text
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      String? responseText = response.text;
      if (responseText == null) return [];

      // Clean up markdown code blocks if present
      responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

      final List<dynamic> jsonList = jsonDecode(responseText);
      
      return jsonList.map((json) {
        final startTimeParts = (json['startTime'] as String).split(':');
        final endTimeParts = (json['endTime'] as String).split(':');
        
        return TimeTableEntry(
          id: const Uuid().v4(),
          subjectName: json['subjectName'],
          type: _parseType(json['type']),
          dayOfWeek: json['dayOfWeek'],
          startTimeHour: int.parse(startTimeParts[0]),
          startTimeMinute: int.parse(startTimeParts[1]),
          endTimeHour: int.parse(endTimeParts[0]),
          endTimeMinute: int.parse(endTimeParts[1]),
        );
      }).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Gemini Parsing Error: $e');
      throw Exception('Failed to parse timetable with AI: $e');
    }
  }

  EntryType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'lab':
        return EntryType.lab;
      case 'tutorial':
        return EntryType.tutorial;
      default:
        return EntryType.lecture;
    }
  }
}
