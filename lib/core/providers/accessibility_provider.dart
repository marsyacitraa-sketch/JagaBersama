import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLargeTextKey = 'jaga_bersama_large_text_mode';

final largeTextModeProvider =
    StateNotifierProvider<LargeTextModeNotifier, bool>((ref) {
  return LargeTextModeNotifier();
});

class LargeTextModeNotifier extends StateNotifier<bool> {
  LargeTextModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kLargeTextKey) ?? false;
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLargeTextKey, next);
  }
}
