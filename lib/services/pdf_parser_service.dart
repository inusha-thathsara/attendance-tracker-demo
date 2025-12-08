import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/timetable_entry.dart';
import '../models/module.dart';
import '../models/enums.dart';

class ParsedData {
  final List<Module> modules;
  final List<TimeTableEntry> classes;

  ParsedData({required this.modules, required this.classes});
}

class PdfParserService {
  Future<({Uint8List bytes, int size, String extension})?> pickTimetableFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // Important for web to get bytes
    );

    if (result != null) {
      final file = result.files.single;
      
      // Check size limit (10MB)
      if (file.size > 10 * 1024 * 1024) {
        throw Exception('File is too large. Maximum size is 10MB.');
      }

      final bytes = file.bytes;
      final Uint8List inputBytes;
      final int size = file.size;
      final String extension = file.extension?.toLowerCase() ?? 'pdf';

      if (bytes != null) {
        inputBytes = bytes;
      } else if (file.path != null) {
        final f = File(file.path!);
        inputBytes = f.readAsBytesSync();
      } else {
        return null;
      }
      
      return (bytes: inputBytes, size: size, extension: extension);
    }
    return null;
  }

  Future<ParsedData> parseFile(Uint8List fileBytes, List<String> apiKeys, String mimeType) async {
    if (apiKeys.isEmpty) {
      throw Exception('No API keys provided.');
    }

    Exception? lastError;

    for (int i = 0; i < apiKeys.length; i++) {
      final apiKey = apiKeys[i];
      try {
        print('Attempting with API Key ${i + 1}/${apiKeys.length}: ${apiKey.substring(0, 5)}...');
        
        // Using gemini-2.5-flash as it supports multimodal input efficiently (Don't change this)
        final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
        final prompt = '''
        You are an intelligent assistant that extracts university timetable data from a document (PDF or Image).
        
        **GOAL**: Extract all valid modules and their corresponding classes/sessions into a structured JSON object.
        
        **OUTPUT FORMAT**:
        Return ONLY a valid JSON object with exactly two keys: "modules" and "classes". Do not include markdown formatting (like ```json).
        
        **JSON STRUCTURE**:
        {
          "modules": [
            {
              "code": "CS101",          // Module Code (e.g., "CS101", "ENG202")
              "name": "Intro to CS",    // Full Module Name
              "credits": 3.0,           // Credit value (number)
              "lecturerName": "Dr. X",  // Lecturer Name
              "note": "Room 101"        // Optional notes. Include details related to the module that don't fit other fields (e.g. "Group A only"). DO NOT include non-academic activities like "Guest Talk" or "Union Hour".
            }
          ],
          "classes": [
            {
              "subjectName": "Intro to CS", // MUST match a Module Name from the "modules" list
              "moduleCode": "CS101",        // MUST match a Module Code from the "modules" list
              "type": "lecture",            // "lecture", "tutorial", or "lab"
              "dayOfWeek": 1,               // 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
              "startTime": "08:00",         // 24-hour format "HH:MM"
              "endTime": "10:00",           // 24-hour format "HH:MM"
              "location": "Hall A",         // Room/Location
              "sessionMode": "physical"     // "physical" or "online"
            }
          ]
        }

        **CRITICAL RULES**:
        1. **NO DUPLICATES**: If a class is listed multiple times (e.g., in a grid or for different groups like G1, G2 at the same time), MERGE them into a single entry.
        2. **MERGE TIME SLOTS**: If a class runs from 8:00-9:00 and 9:00-10:00, combine it into a single 8:00-10:00 session.
        3. **CONSISTENCY**: The `moduleCode` in a class MUST exist in the `modules` list. If a class has no corresponding module, IGNORE IT.
        4. **DEFAULTS**:
           - If type is unclear, use "lecture".
           - If "Lab", "Practical", or "L" is found, use "lab".
           - If "Tutorial" or "T" is found, use "tutorial".
           - If session mode is unspecified, use "physical".
        5. **SKIP NON-ACADEMIC**: Do not extract sessions that are purely non-academic (like "Lunch", "Break", "Library", "Union Hour", "Guest Talk"). Do NOT add these to module notes.
        6. **IGNORE**: Headers, footers, page numbers.

        **DOCUMENT CONTENT**:
        (See attached file data)
        ''';

        final content = [
          Content.multi([
            TextPart(prompt),
            DataPart(mimeType, fileBytes),
          ])
        ];

        final response = await model.generateContent(content);
        
        String? responseText = response.text;
        if (responseText == null) return ParsedData(modules: [], classes: []);

        // Clean up markdown code blocks if present
        responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

        final Map<String, dynamic> jsonResult = jsonDecode(responseText);
        
        // Parse and De-duplicate Modules
        final Map<String, Module> uniqueModules = {};
        for (var m in (jsonResult['modules'] as List<dynamic>? ?? [])) {
          final code = (m['code'] ?? '').toString().trim().toUpperCase();
          final module = Module(
            code: code,
            name: m['name'] ?? '',
            credits: (m['credits'] ?? 0).toDouble(),
            lecturerName: m['lecturerName'] ?? '',
            note: m['note'],
          );
          if (module.code.isNotEmpty) {
            uniqueModules[module.code] = module;
          }
        }

        // Parse, Filter, and De-duplicate Classes
        List<TimeTableEntry> classes = [];
        final Set<String> seenClasses = {};

        for (var c in (jsonResult['classes'] as List<dynamic>? ?? [])) {
          final moduleCode = (c['moduleCode'] ?? '').toString().trim().toUpperCase();
          
          // Rule: There can only be classes where there is a module on that name.
          if (!uniqueModules.containsKey(moduleCode)) {
            continue; 
          }

          final startTimeParts = (c['startTime'] as String).split(':');
          final endTimeParts = (c['endTime'] as String).split(':');
          
          // Use the Module Name as the Subject Name to ensure consistency and merge groups (G1, G2)
          final subjectName = uniqueModules[moduleCode]!.name;

          final entry = TimeTableEntry(
            id: const Uuid().v4(),
            subjectName: subjectName,
            moduleCode: moduleCode,
            type: _parseType(c['type']),
            dayOfWeek: c['dayOfWeek'] ?? 1,
            startTimeHour: int.parse(startTimeParts[0]),
            startTimeMinute: int.parse(startTimeParts[1]),
            endTimeHour: int.parse(endTimeParts[0]),
            endTimeMinute: int.parse(endTimeParts[1]),
            location: c['location'],
            sessionMode: _parseSessionMode(c['sessionMode']),
          );

          // Create a unique key for de-duplication: ModuleCode + Day + StartTime + EndTime
          // This merges different groups (G1, G2) if they are at the same time for the same module.
          final key = '$moduleCode-${entry.dayOfWeek}-${entry.startTimeHour}:${entry.startTimeMinute}-${entry.endTimeHour}:${entry.endTimeMinute}';
          
          if (!seenClasses.contains(key)) {
            seenClasses.add(key);
            classes.add(entry);
          }
        }

        // Post-processing: Merge overlapping and consecutive slots
        // Group by unique identifier (excluding time) to find mergeable candidates
        // We need to sort first to ensure we merge in order
        classes.sort((a, b) {
          if (a.dayOfWeek != b.dayOfWeek) return a.dayOfWeek.compareTo(b.dayOfWeek);
          int startA = a.startTimeHour * 60 + a.startTimeMinute;
          int startB = b.startTimeHour * 60 + b.startTimeMinute;
          return startA.compareTo(startB);
        });

        final List<TimeTableEntry> mergedClasses = [];
        if (classes.isNotEmpty) {
          TimeTableEntry current = classes.first;
          
          for (int i = 1; i < classes.length; i++) {
            final next = classes[i];
            
            // Check if same module, day, type, location, and session mode
            bool isSameContext = current.moduleCode == next.moduleCode &&
                current.dayOfWeek == next.dayOfWeek &&
                current.type == next.type &&
                current.location == next.location &&
                current.sessionMode == next.sessionMode;
                
            if (isSameContext) {
               int currentStart = current.startTimeHour * 60 + current.startTimeMinute;
               int currentEnd = current.endTimeHour * 60 + current.endTimeMinute;
               int nextStart = next.startTimeHour * 60 + next.startTimeMinute;
               int nextEnd = next.endTimeHour * 60 + next.endTimeMinute;

               // Since sorted, currentStart <= nextStart.
               
               // Check for overlap or consecutive
               // Overlap: nextStart < currentEnd
               // Consecutive: nextStart == currentEnd
               if (nextStart <= currentEnd) {
                   // Merge: New End is max of both
                   int newEnd = (currentEnd > nextEnd) ? currentEnd : nextEnd;
                   
                   current = TimeTableEntry(
                      id: current.id,
                      subjectName: current.subjectName,
                      moduleCode: current.moduleCode,
                      type: current.type,
                      dayOfWeek: current.dayOfWeek,
                      startTimeHour: current.startTimeHour,
                      startTimeMinute: current.startTimeMinute,
                      endTimeHour: newEnd ~/ 60,
                      endTimeMinute: newEnd % 60,
                      location: current.location,
                      sessionMode: current.sessionMode,
                      timetableId: current.timetableId,
                   );
                   continue; // Skip adding 'next', we merged it into 'current' (or kept current if it contained next)
               }
            }
            
            mergedClasses.add(current);
            current = next;
          }
          mergedClasses.add(current);
        }

        return ParsedData(modules: uniqueModules.values.toList(), classes: mergedClasses);

      } catch (e) {
        print('Error with Key ${i + 1}: $e');
        lastError = e is Exception ? e : Exception(e.toString());
        // If this was the last key, we'll exit the loop and throw
        if (i == apiKeys.length - 1) {
          throw lastError;
        }
        // Otherwise continue to next key
      }
    }
    throw lastError ?? Exception('Failed to parse with any API key.');
  }

  EntryType _parseType(String? type) {
    if (type == null) return EntryType.lecture;
    switch (type.toLowerCase()) {
      case 'lab':
        return EntryType.lab;
      case 'tutorial':
        return EntryType.tutorial;
      default:
        return EntryType.lecture;
    }
  }

  SessionMode _parseSessionMode(String? mode) {
    if (mode == null) return SessionMode.physical;
    switch (mode.toLowerCase()) {
      case 'online':
        return SessionMode.online;
      default:
        return SessionMode.physical;
    }
  }
}
