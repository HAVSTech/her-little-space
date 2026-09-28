import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const moodKey = 'mood';
  static const symptomsKey = 'symptoms';
  static const darkKey = 'dark_theme';

  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  Future<String?> loadMood() async => (await prefs).getString(moodKey);
  Future<Set<String>> loadSymptoms() async =>
      ((await prefs).getStringList(symptomsKey) ?? const <String>[]).toSet();
  Future<bool> loadDark() async => (await prefs).getBool(darkKey) ?? false;

  Future<void> saveMood(String? value) async {
    final p = await prefs;
    if (value == null) {
      await p.remove(moodKey);
    } else {
      await p.setString(moodKey, value);
    }
  }

  Future<void> saveSymptoms(Set<String> values) async =>
      (await prefs).setStringList(symptomsKey, values.toList());

  Future<void> saveDark(bool value) async =>
      (await prefs).setBool(darkKey, value);
}
