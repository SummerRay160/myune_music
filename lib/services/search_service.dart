import 'dart:math';
import '../page/playlist/playlist_models.dart';
import 'pinyin_cache.dart';

class SongSearchIndex {
  final Song song;
  final String titleLower;
  final String artistLower;
  final String titlePinyin;
  final String artistPinyin;
  final String titleInitials;
  final String artistInitials;

  SongSearchIndex(this.song)
    : titleLower = song.title.toLowerCase(),
      artistLower = song.artist.toLowerCase(),
      titlePinyin = PinyinCache.instance.getFullPinyin(song.title),
      artistPinyin = PinyinCache.instance.getFullPinyin(song.artist),
      titleInitials = PinyinCache.instance.getInitials(song.title),
      artistInitials = PinyinCache.instance.getInitials(song.artist);

  SongSearchIndex.fromPersisted(
    this.song, {
    required this.titlePinyin,
    required this.artistPinyin,
    required this.titleInitials,
    required this.artistInitials,
  }) : titleLower = song.title.toLowerCase(),
       artistLower = song.artist.toLowerCase();
}

enum SearchMatchType { exact, pinyinInitial, pinyinFull, fuzzy }

class SearchResult {
  final Song song;
  final double score;
  final SearchMatchType matchType;

  SearchResult({
    required this.song,
    required this.score,
    required this.matchType,
  });
}

class SearchService {
  List<SearchResult> search(String keyword, List<SongSearchIndex> indices) {
    if (keyword.isEmpty) return [];

    final query = keyword.toLowerCase().trim();
    final isLatin = _isLatinOnly(query);
    final results = <SearchResult>[];

    for (final index in indices) {
      double maxScore = -1.0;
      SearchMatchType bestMatch = SearchMatchType.fuzzy;

      // 1: 精确匹配
      if (index.titleLower.contains(query) ||
          index.artistLower.contains(query)) {
        double score = 100.0;
        if (index.titleLower == query) score += 20;
        if (index.artistLower == query) score += 10;

        if (score > maxScore) {
          maxScore = score;
          bestMatch = SearchMatchType.exact;
        }
      }

      // 2: 初步拼音匹配
      if (isLatin && maxScore < 100) {
        if (index.titleInitials.contains(query) ||
            index.artistInitials.contains(query)) {
          double score = 80.0;
          if (index.titleInitials.startsWith(query)) score += 10;

          if (score > maxScore) {
            maxScore = score;
            bestMatch = SearchMatchType.pinyinInitial;
          }
        }
      }

      // 3: 完整拼音匹配
      if (isLatin && maxScore < 80) {
        if (index.titlePinyin.contains(query) ||
            index.artistPinyin.contains(query)) {
          double score = 60.0;
          if (index.titlePinyin.startsWith(query)) score += 10;

          if (score > maxScore) {
            maxScore = score;
            bestMatch = SearchMatchType.pinyinFull;
          }
        }
      }

      // 4: 模糊子序列匹配
      if (maxScore < 60) {
        final titleFuzzy = fuzzyMatch(query, index.titleLower);
        final artistFuzzy = fuzzyMatch(query, index.artistLower);
        final fuzzyScore = max(titleFuzzy, artistFuzzy);

        if (fuzzyScore > maxScore && fuzzyScore > 0) {
          maxScore = fuzzyScore;
          bestMatch = SearchMatchType.fuzzy;
        }
      }

      if (maxScore > 0) {
        results.add(
          SearchResult(song: index.song, score: maxScore, matchType: bestMatch),
        );
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  double fuzzyMatch(String query, String target) {
    if (query.isEmpty) return 0.0;
    if (target.isEmpty) return -1.0;

    int qIdx = 0;
    int tIdx = 0;
    int lastMatchIdx = -1;
    double score = 0.0;

    while (qIdx < query.length && tIdx < target.length) {
      if (query[qIdx] == target[tIdx]) {
        score += 1;

        if (lastMatchIdx != -1) {
          final gap = tIdx - lastMatchIdx - 1;
          if (gap == 0) {
            score += 3; // 连续匹配加分
          } else if (gap == 1) {
            score += 5; // 紧凑匹配加分
          } else if (gap <= 3) {
            score += 2;
          }
        } else {
          if (tIdx == 0) {
            score += 10;
          } else if (target[tIdx - 1] == ' ' || target[tIdx - 1] == '-') {
            score += 8;
          }
        }

        lastMatchIdx = tIdx;
        qIdx++;
      }
      tIdx++;
    }

    if (qIdx < query.length) {
      return -1.0; // 没有全部匹配上
    }

    if (query == target) {
      score += 20;
    } else if (target.contains(query)) {
      score += 15;
    }

    score += (query.length / target.length) * 5;
    return score;
  }

  bool _isLatinOnly(String text) {
    final regex = RegExp(r'^[a-z0-9\s]+$');
    return regex.hasMatch(text);
  }
}
