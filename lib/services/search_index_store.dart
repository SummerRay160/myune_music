import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pinyin/pinyin.dart';
import '../page/playlist/playlist_models.dart';
import 'search_service.dart';

class PersistedIndexEntry {
  final String filePath;
  final int contentHash;
  final String titlePinyin;
  final String artistPinyin;
  final String titleInitials;
  final String artistInitials;

  PersistedIndexEntry({
    required this.filePath,
    required this.contentHash,
    required this.titlePinyin,
    required this.artistPinyin,
    required this.titleInitials,
    required this.artistInitials,
  });

  Map<String, dynamic> toJson() {
    return {
      'h': contentHash,
      'tp': titlePinyin,
      'ap': artistPinyin,
      'ti': titleInitials,
      'ai': artistInitials,
    };
  }

  factory PersistedIndexEntry.fromJson(
    String filePath,
    Map<String, dynamic> json,
  ) {
    return PersistedIndexEntry(
      filePath: filePath,
      contentHash: json['h'] as int? ?? 0,
      titlePinyin: json['tp'] as String? ?? '',
      artistPinyin: json['ap'] as String? ?? '',
      titleInitials: json['ti'] as String? ?? '',
      artistInitials: json['ai'] as String? ?? '',
    );
  }

  factory PersistedIndexEntry.build(
    String title,
    String artist, {
    required String filePath,
  }) {
    final hash = '$title|$artist'.hashCode;

    String getPinyin(String text) {
      final buffer = StringBuffer();
      for (final rune in text.runes) {
        final char = String.fromCharCode(rune);
        final py = PinyinHelper.getPinyin(char, separator: '');
        buffer.write(
          py.isNotEmpty && py != char ? py.toLowerCase() : char.toLowerCase(),
        );
      }
      return buffer.toString();
    }

    String getInitials(String text) {
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
    }

    return PersistedIndexEntry(
      filePath: filePath,
      contentHash: hash,
      titlePinyin: getPinyin(title),
      artistPinyin: getPinyin(artist),
      titleInitials: getInitials(title),
      artistInitials: getInitials(artist),
    );
  }
}

class _SongIdentity {
  final String filePath;
  final String title;
  final String artist;

  _SongIdentity({
    required this.filePath,
    required this.title,
    required this.artist,
  });
}

class _IndexBuildParams {
  final Map<String, PersistedIndexEntry> cachedEntries;
  final List<_SongIdentity> songs;

  _IndexBuildParams(this.cachedEntries, this.songs);
}

class _IndexBuildResult {
  final Map<String, PersistedIndexEntry> entries;
  final bool needsPersist;

  _IndexBuildResult(this.entries, this.needsPersist);
}

_IndexBuildResult _buildIndexInIsolate(_IndexBuildParams params) {
  final newEntries = <String, PersistedIndexEntry>{};
  bool isDirty = false;

  for (final song in params.songs) {
    final currentHash = '${song.title}|${song.artist}'.hashCode;
    final cached = params.cachedEntries[song.filePath];

    if (cached != null && cached.contentHash == currentHash) {
      newEntries[song.filePath] = cached;
    } else {
      isDirty = true;
      newEntries[song.filePath] = PersistedIndexEntry.build(
        song.title,
        song.artist,
        filePath: song.filePath,
      );
    }
  }

  return _IndexBuildResult(newEntries, isDirty);
}

class IndexUpdateResult {
  final List<SongSearchIndex> indices;
  final Map<String, PersistedIndexEntry> entries;

  IndexUpdateResult(this.indices, this.entries);
}

class SearchIndexStore {
  Future<File> _getIndexFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/myune_music/search_index.json';
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return file;
  }

  Future<Map<String, PersistedIndexEntry>> loadFromDisk() async {
    try {
      final file = await _getIndexFile();
      if (!await file.exists()) {
        return {};
      }

      final content = await file.readAsString();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;

      if (jsonMap['version'] != 1 || jsonMap['entries'] == null) {
        return {};
      }

      final entriesJson = jsonMap['entries'] as Map<String, dynamic>;
      final result = <String, PersistedIndexEntry>{};

      entriesJson.forEach((key, value) {
        result[key] = PersistedIndexEntry.fromJson(
          key,
          value as Map<String, dynamic>,
        );
      });

      return result;
    } catch (e) {
      debugPrint('Error loading search index: $e');
      return {};
    }
  }

  Future<void> saveToDisk(Map<String, PersistedIndexEntry> entries) async {
    try {
      final file = await _getIndexFile();

      final entriesJson = <String, dynamic>{};
      entries.forEach((key, value) {
        entriesJson[key] = value.toJson();
      });

      final jsonMap = {'version': 1, 'entries': entriesJson};

      await file.writeAsString(jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('Error saving search index: $e');
    }
  }

  Future<IndexUpdateResult> buildIndex(List<Song> songs) async {
    final cachedEntries = await loadFromDisk();

    final identities = songs
        .map(
          (s) => _SongIdentity(
            filePath: s.filePath,
            title: s.title,
            artist: s.artist,
          ),
        )
        .toList();

    final params = _IndexBuildParams(cachedEntries, identities);
    final result = await compute(_buildIndexInIsolate, params);

    if (result.needsPersist) {
      saveToDisk(result.entries);
    }

    final indices = <SongSearchIndex>[];
    for (final song in songs) {
      final entry = result.entries[song.filePath];
      if (entry != null) {
        indices.add(
          SongSearchIndex.fromPersisted(
            song,
            titlePinyin: entry.titlePinyin,
            artistPinyin: entry.artistPinyin,
            titleInitials: entry.titleInitials,
            artistInitials: entry.artistInitials,
          ),
        );
      } else {
        indices.add(SongSearchIndex(song));
      }
    }

    return IndexUpdateResult(indices, result.entries);
  }
}
