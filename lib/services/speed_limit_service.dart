import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Fetches the speed limit of the road at a given GPS coordinate
/// using the Overpass API (OpenStreetMap data).
///
/// When OSM has no explicit maxspeed tag, a fallback is derived from the
/// road type (highway=* tag) so the system always has a limit to enforce.
class SpeedLimitService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  // Cache: avoid hammering the API on every GPS update
  double? _cachedLat;
  double? _cachedLng;
  int? _cachedSpeedLimit;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(seconds: 15);

  // Minimum movement (~50 m) before re-querying
  static const _minMoveDeg = 0.0005;

  /// Returns the speed limit in km/h.
  /// Guaranteed non-null: falls back to a road-type default when OSM has no tag.
  Future<int> getSpeedLimit(double lat, double lng) async {
    // Return cached value if close enough and recent
    if (_cachedLat != null &&
        _cachedLng != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration &&
        (lat - _cachedLat!).abs() < _minMoveDeg &&
        (lng - _cachedLng!).abs() < _minMoveDeg) {
      return _cachedSpeedLimit ?? _defaultLimit();
    }

    try {
      // Query roads within 35 m — do NOT filter by [maxspeed] so we always
      // get at least the road type even when the maxspeed tag is absent.
      final query = '''
[out:json][timeout:8];
(
  way(around:35,$lat,$lng)[highway];
);
out tags;
''';

      final response = await http
          .post(
            Uri.parse(_overpassUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'data=${Uri.encodeComponent(query)}',
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];

        if (elements.isNotEmpty) {
          // Prefer the element that has an explicit maxspeed tag
          Map<String, dynamic>? bestTags;
          for (final el in elements) {
            final t = el['tags'] as Map<String, dynamic>?;
            if (t != null && t.containsKey('maxspeed')) {
              bestTags = t;
              break;
            }
          }
          // Fall back to first element (no maxspeed tag)
          bestTags ??= elements[0]['tags'] as Map<String, dynamic>?;

          if (bestTags != null) {
            final maxspeedStr = bestTags['maxspeed'] as String?;
            final highway    = bestTags['highway'] as String? ?? 'residential';

            final limit = (maxspeedStr != null)
                ? _parseMaxspeed(maxspeedStr) ?? _defaultForHighway(highway)
                : _defaultForHighway(highway);

            _cachedLat = lat;
            _cachedLng = lng;
            _cachedSpeedLimit = limit;
            _cacheTime = DateTime.now();
            debugPrint(
              '[SpeedLimit] $highway | maxspeed="${maxspeedStr ?? "none"}" → $limit km/h',
            );
            return limit;
          }
        }
      } else {
        debugPrint('[SpeedLimit] HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[SpeedLimit] Error: $e');
    }

    // API unavailable or no road found — return cached value or hard default
    return _cachedSpeedLimit ?? _defaultLimit();
  }

  /// Safe fallback when no road info is available at all.
  int _defaultLimit() => 50;

  /// Speed limit default based on OSM highway classification.
  /// Values reflect common defaults used in India (and most countries).
  int _defaultForHighway(String highway) {
    switch (highway.toLowerCase()) {
      case 'motorway':
      case 'motorway_link':
        return 100;
      case 'trunk':
      case 'trunk_link':
        return 80;
      case 'primary':
      case 'primary_link':
        return 60;
      case 'secondary':
      case 'secondary_link':
        return 50;
      case 'tertiary':
      case 'tertiary_link':
        return 40;
      case 'residential':
      case 'unclassified':
        return 30;
      case 'service':
      case 'living_street':
        return 20;
      case 'pedestrian':
      case 'footway':
      case 'path':
        return 10;
      default:
        return 50; // urban default
    }
  }

  /// Parses OSM maxspeed values:
  /// "50", "50 mph", "30 mph", "walk", "none", "in:urban", etc.
  int? _parseMaxspeed(String raw) {
    raw = raw.trim().toLowerCase();
    if (raw == 'walk' || raw == 'living_street') return 10;
    if (raw == 'none' || raw == 'unlimited')     return null; // no limit
    if (raw == 'urban' || raw == 'ru:urban' || raw == 'in:urban')   return 50;
    if (raw == 'rural' || raw == 'ru:rural' || raw == 'in:rural')   return 80;
    if (raw == 'motorway' || raw == 'ru:motorway' || raw == 'in:motorway') return 100;

    // "X mph" → convert to km/h
    if (raw.contains('mph')) {
      final mph = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (mph != null) return (mph * 1.60934).round();
    }

    // Plain numeric (km/h)
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  void clearCache() {
    _cachedLat = null;
    _cachedLng = null;
    _cachedSpeedLimit = null;
    _cacheTime = null;
  }
}
