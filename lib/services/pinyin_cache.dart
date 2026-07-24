import 'package:pinyin/pinyin.dart';

// 替代目前在 build() 中的局部缓存，避免重复计算
class PinyinCache {
  static final PinyinCache _instance = PinyinCache._();
  static PinyinCache get instance => _instance;
  PinyinCache._();

  final Map<String, String> _fullPinyinCache = {};
  final Map<String, String> _initialsCache = {};

  // 获取全拼
  // 例: "周杰伦" -> "zhoujielun"
  String getFullPinyin(String text) {
    return _fullPinyinCache.putIfAbsent(text, () {
      final buffer = StringBuffer();
      for (final rune in text.runes) {
        final char = String.fromCharCode(rune);
        final py = PinyinHelper.getPinyin(char, separator: '');
        buffer.write(
          py.isNotEmpty && py != char ? py.toLowerCase() : char.toLowerCase(),
        );
      }
      return buffer.toString();
    });
  }

  // 获取首字母
  // 例: "周杰伦" -> "zjl"
  String getInitials(String text) {
    return _initialsCache.putIfAbsent(text, () {
      final buffer = StringBuffer();
      for (final rune in text.runes) {
        final char = String.fromCharCode(rune);
        final py = PinyinHelper.getPinyin(char, separator: '');
        if (py.isNotEmpty && py != char) {
          buffer.write(py[0].toLowerCase());
        } else {
          buffer.write(char.toLowerCase());
        }
      }
      return buffer.toString();
    });
  }

  // 歌曲库变更时清除缓存
  void invalidate() {
    _fullPinyinCache.clear();
    _initialsCache.clear();
  }
}
