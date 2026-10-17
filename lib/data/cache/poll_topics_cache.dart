import 'package:flutter/foundation.dart';
import '../../api/api_service.dart';
import '../../models/poll/poll_topic_model.dart';

class PollTopicsCache {
  static List<PollTopicModel>? _cachedTopics;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 15);
  static Future<List<PollTopicModel>>? _ongoingFetch;

  static bool get hasCache =>
      _cachedTopics != null && _cachedTopics!.isNotEmpty;

  static List<PollTopicModel> get topics => _cachedTopics ?? const [];

  static bool get isExpired {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _cacheDuration;
  }

  static void setTopics(List<PollTopicModel> topics) {
    _cachedTopics = List.from(topics);
    _lastFetchTime = DateTime.now();
  }

  static Future<List<PollTopicModel>> loadTopics({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && hasCache && !isExpired) {
      return _cachedTopics!;
    }

    if (_ongoingFetch != null) {
      return _ongoingFetch!;
    }

    _ongoingFetch = _fetchInternal();
    try {
      final result = await _ongoingFetch!;
      return result;
    } finally {
      _ongoingFetch = null;
    }
  }

  static Future<List<PollTopicModel>> _fetchInternal() async {
    try {
      final response = await ApiService().getPollTopicsFeed();
      final feedTopics = PollTopicModel.fromFeedResponse(response);
      if (feedTopics.isNotEmpty) {
        setTopics(feedTopics);
      }
      return _cachedTopics ?? feedTopics;
    } catch (e) {
      debugPrint('PollTopicsCache error fetching feed: $e');
      if (hasCache) {
        return _cachedTopics!;
      }
      rethrow;
    }
  }

  static void clear() {
    _cachedTopics = null;
    _lastFetchTime = null;
  }
}
