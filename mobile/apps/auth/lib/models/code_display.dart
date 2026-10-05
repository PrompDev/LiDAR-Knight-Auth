import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class CodeDisplay {
  final bool pinned;
  final bool trashed;
  final int lastUsedAt;
  final int tapCount;
  String note;
  final List<String> tags;
  int position;
  String iconSrc;
  String iconID;
  final String lidarSeat;
  final bool lidarLocked;
  final int lidarGeneration;
  // LiDAR emailed admin key (format 2, EMAIL-KEY-CONTRACT-v2 v2.3). A row
  // without these keys in its stored JSON is a format-1 master card, exactly
  // as Auth 4.4.29 stored it; they are written to JSON only for format 2.
  final int lidarFormat;
  final String lidarIssuer;
  final String lidarEmail;
  final String lidarActivationId;
  final String lidarState;
  final String lidarReason;
  final String lidarActivateBy;

  CodeDisplay({
    this.pinned = false,
    this.trashed = false,
    this.lastUsedAt = 0,
    this.tapCount = 0,
    this.tags = const [],
    this.note = '',
    this.position = 0,
    this.iconSrc = '',
    this.iconID = '',
    this.lidarSeat = '',
    this.lidarLocked = false,
    this.lidarGeneration = 0,
    this.lidarFormat = 1,
    this.lidarIssuer = '',
    this.lidarEmail = '',
    this.lidarActivationId = '',
    this.lidarState = '',
    this.lidarReason = '',
    this.lidarActivateBy = '',
  });

  bool get isCustomIcon => (iconSrc != '' && iconID != '');

  CodeDisplay copyWith({
    bool? pinned,
    bool? trashed,
    int? lastUsedAt,
    int? tapCount,
    List<String>? tags,
    String? note,
    int? position,
    String? iconSrc,
    String? iconID,
    String? lidarSeat,
    bool? lidarLocked,
    int? lidarGeneration,
    int? lidarFormat,
    String? lidarIssuer,
    String? lidarEmail,
    String? lidarActivationId,
    String? lidarState,
    String? lidarReason,
    String? lidarActivateBy,
  }) {
    final bool updatedPinned = pinned ?? this.pinned;
    final bool updatedTrashed = trashed ?? this.trashed;
    final int updatedLastUsedAt = lastUsedAt ?? this.lastUsedAt;
    final int updatedTapCount = tapCount ?? this.tapCount;
    final List<String> updatedTags = tags ?? this.tags;
    final String updatedNote = note ?? this.note;
    final int updatedPosition = position ?? this.position;
    final String updatedIconSrc = iconSrc ?? this.iconSrc;
    final String updatedIconID = iconID ?? this.iconID;

    return CodeDisplay(
      pinned: updatedPinned,
      trashed: updatedTrashed,
      lastUsedAt: updatedLastUsedAt,
      tapCount: updatedTapCount,
      tags: updatedTags,
      note: updatedNote,
      position: updatedPosition,
      iconSrc: updatedIconSrc,
      iconID: updatedIconID,
      lidarSeat: lidarSeat ?? this.lidarSeat,
      lidarLocked: lidarLocked ?? this.lidarLocked,
      lidarGeneration: lidarGeneration ?? this.lidarGeneration,
      lidarFormat: lidarFormat ?? this.lidarFormat,
      lidarIssuer: lidarIssuer ?? this.lidarIssuer,
      lidarEmail: lidarEmail ?? this.lidarEmail,
      lidarActivationId: lidarActivationId ?? this.lidarActivationId,
      lidarState: lidarState ?? this.lidarState,
      lidarReason: lidarReason ?? this.lidarReason,
      lidarActivateBy: lidarActivateBy ?? this.lidarActivateBy,
    );
  }

  factory CodeDisplay.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return CodeDisplay();
    }
    // Format-2 metadata is read only from a row that says it is format 2.
    final bool format2 = json['lidarFormat'] == 2;
    String v2(String key) =>
        format2 && json[key] is String ? json[key] as String : '';
    return CodeDisplay(
      pinned: json['pinned'] ?? false,
      trashed: json['trashed'] ?? false,
      lastUsedAt: json['lastUsedAt'] ?? 0,
      tapCount: json['tapCount'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      note: json['note'] ?? '',
      position: json['position'] ?? 0,
      iconSrc: json['iconSrc'] ?? 'ente',
      iconID: json['iconID'] ?? '',
      lidarSeat: json['lidarSeat'] is String ? json['lidarSeat'] : '',
      lidarLocked: json['lidarLocked'] == true,
      lidarGeneration: json['lidarGeneration'] is int
          ? json['lidarGeneration']
          : 0,
      lidarFormat: format2 ? 2 : 1,
      lidarIssuer: v2('lidarIssuer'),
      lidarEmail: v2('lidarEmail'),
      lidarActivationId: v2('lidarActivationId'),
      lidarState: v2('lidarState'),
      lidarReason: v2('lidarReason'),
      lidarActivateBy: v2('lidarActivateBy'),
    );
  }

  static CodeDisplay? fromUri(Uri uri, {bool safeParsing = false}) {
    if (!uri.queryParameters.containsKey("codeDisplay")) return null;
    final String codeDisplay = uri.queryParameters['codeDisplay']!.replaceAll(
      '%2C',
      ',',
    );
    return _parseCodeDisplayJson(codeDisplay, safeParsing);
  }

  static CodeDisplay _parseCodeDisplayJson(String json, bool safeParsing) {
    try {
      final decodedDisplay = jsonDecode(json);
      return CodeDisplay.fromJson(decodedDisplay);
    } catch (e, s) {
      Logger(
        "CodeDisplay",
      ).severe("Could not parse code display from json", e, s);
      // Ignore legacy codeDisplay JSON followed by an unescaped URL fragment.
      if (!json.endsWith("}") && json.contains("}#")) {
        Logger("CodeDisplay").warning("ignoring code display as it's invalid");
        return CodeDisplay();
      }
      if (safeParsing) {
        return CodeDisplay();
      } else {
        rethrow;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'pinned': pinned,
      'trashed': trashed,
      'lastUsedAt': lastUsedAt,
      'tapCount': tapCount,
      'tags': tags,
      'note': note,
      'position': position,
      'iconSrc': iconSrc,
      'iconID': iconID,
      'lidarSeat': lidarSeat,
      'lidarLocked': lidarLocked,
      'lidarGeneration': lidarGeneration,
      if (lidarFormat == 2) ...{
        'lidarFormat': 2,
        'lidarIssuer': lidarIssuer,
        'lidarEmail': lidarEmail,
        'lidarActivationId': lidarActivationId,
        'lidarState': lidarState,
        'lidarReason': lidarReason,
        'lidarActivateBy': lidarActivateBy,
      },
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CodeDisplay &&
        other.pinned == pinned &&
        other.trashed == trashed &&
        other.lastUsedAt == lastUsedAt &&
        other.tapCount == tapCount &&
        other.note == note &&
        other.lidarSeat == lidarSeat &&
        other.lidarLocked == lidarLocked &&
        other.lidarGeneration == lidarGeneration &&
        other.lidarFormat == lidarFormat &&
        other.lidarIssuer == lidarIssuer &&
        other.lidarEmail == lidarEmail &&
        other.lidarActivationId == lidarActivationId &&
        other.lidarState == lidarState &&
        other.lidarReason == lidarReason &&
        other.lidarActivateBy == lidarActivateBy &&
        listEquals(other.tags, tags);
  }

  @override
  int get hashCode {
    return pinned.hashCode ^
        trashed.hashCode ^
        lastUsedAt.hashCode ^
        tapCount.hashCode ^
        note.hashCode ^
        lidarSeat.hashCode ^
        lidarLocked.hashCode ^
        lidarGeneration.hashCode ^
        lidarFormat.hashCode ^
        lidarIssuer.hashCode ^
        lidarEmail.hashCode ^
        lidarActivationId.hashCode ^
        lidarState.hashCode ^
        lidarReason.hashCode ^
        lidarActivateBy.hashCode ^
        tags.hashCode;
  }
}
