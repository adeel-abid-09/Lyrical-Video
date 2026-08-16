import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/editor_project_model.dart';

class ProjectStorageService {
  static const String _storageKey = 'saved_lyrical_projects';

  static Future<List<EditorProjectModel>> loadSavedProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => EditorProjectModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveProject(EditorProjectModel project) async {
    try {
      final projects = await loadSavedProjects();
      final existingIndex = projects.indexWhere((p) => p.id == project.id);

      if (existingIndex >= 0) {
        projects[existingIndex] = project;
      } else {
        projects.insert(0, project);
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(projects.map((p) => p.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      // Storage save error handling
    }
  }

  static Future<void> deleteProject(String id) async {
    try {
      final projects = await loadSavedProjects();
      projects.removeWhere((p) => p.id == id);

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(projects.map((p) => p.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);

      final restoreId = prefs.getString('editor_restore_session_id');
      if (restoreId == id) {
        await prefs.remove('editor_restore_session_id');
      }
      final activeId = prefs.getString('active_session_id');
      if (activeId == id) {
        await prefs.remove('active_session_id');
      }
    } catch (e) {
      // Delete error handling
    }
  }
}
