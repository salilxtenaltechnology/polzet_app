import 'package:flutter/foundation.dart';
import 'package:polzet_app/api/api_config.dart';

class PollResultResponse {
  final String status;
  final String message;
  final PollResultData data;

  PollResultResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory PollResultResponse.fromJson(Map<String, dynamic> json) {
    return PollResultResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: PollResultData.fromJson(json['data'] ?? {}),
    );
  }
}

class PollResultData {
  final int pollId;
  final int totalVotes;
  final int totalWeightedScore;
  final List<PollOption> results;
  final List<IndividualResult> individualResults;

  PollResultData({
    required this.pollId,
    required this.totalVotes,
    required this.totalWeightedScore,
    required this.results,
    required this.individualResults,
  });

  factory PollResultData.fromJson(Map<String, dynamic> json) {
    final List<PollOption> parsedResults = [];
    if (json['results'] != null && json['results'] is List) {
      for (var e in json['results']) {
        if (e is Map<String, dynamic>) {
          try {
            parsedResults.add(PollOption.fromJson(e));
          } catch (err) {
            debugPrint('Error parsing PollOption: $err');
          }
        }
      }
    }

    final List<IndividualResult> parsedIndividual = [];
    if (json['individual_results'] != null && json['individual_results'] is List) {
      for (var e in json['individual_results']) {
        if (e is Map<String, dynamic>) {
          try {
            parsedIndividual.add(IndividualResult.fromJson(e));
          } catch (err) {
            debugPrint('Error parsing IndividualResult: $err');
          }
        }
      }
    }

    return PollResultData(
      pollId: json['poll_id'] ?? 0,
      totalVotes: json['total_votes'] ?? 0,
      totalWeightedScore: json['total_weighted_score'] ?? 0,
      results: parsedResults,
      individualResults: parsedIndividual,
    );
  }
}

class PollOption {
  final int optionId;
  final String? text;
  final String? imageUrl;
  final int rank1Count;
  final Map<String, int> rankDistribution;
  final int score;
  final double percentage;

  PollOption({
    required this.optionId,
    this.text,
    this.imageUrl,
    required this.rank1Count,
    required this.rankDistribution,
    required this.score,
    required this.percentage,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    final Map<String, int> parsedDistribution = {};
    if (json['rank_distribution'] != null && json['rank_distribution'] is Map) {
      (json['rank_distribution'] as Map).forEach((key, value) {
        parsedDistribution[key.toString()] = int.tryParse(value.toString()) ?? 0;
      });
    }

    return PollOption(
      optionId: json['option_id'] ?? 0,
      text: json['text'],
      imageUrl: json['image_url'],
      rank1Count: json['rank_1_count'] ?? 0,
      rankDistribution: parsedDistribution,
      score: json['score'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class IndividualResult {
  final PollUser user;
  final List<UserRank> ranks;
  final String? votedAt;

  IndividualResult({
    required this.user,
    required this.ranks,
    this.votedAt,
  });

  factory IndividualResult.fromJson(Map<String, dynamic> json) {
    final List<UserRank> parsedRanks = [];
    if (json['ranks'] != null && json['ranks'] is List) {
      for (var e in json['ranks']) {
        if (e is Map<String, dynamic>) {
          try {
            parsedRanks.add(UserRank.fromJson(e));
          } catch (err) {
            debugPrint('Error parsing UserRank: $err');
          }
        }
      }
    }

    return IndividualResult(
      user: PollUser.fromJson(json['user'] ?? {}),
      ranks: parsedRanks,
      votedAt: json['voted_at']?.toString() ?? json['created_at']?.toString(),
    );
  }
}

class PollUser {
  final String id;
  final String username;
  final String fullName;
  final String? profilePictureUrl;

  PollUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.profilePictureUrl,
  });

  factory PollUser.fromJson(Map<String, dynamic> json) {
    String? profilePic = json['profile_picture_url'] as String?;
    if (profilePic != null && profilePic.isNotEmpty) {
      if (!profilePic.startsWith('http') && !profilePic.startsWith('data:image')) {
        if (profilePic.startsWith('/')) {
          profilePic = '${ApiConfig.baseUrlImage}$profilePic';
        } else {
          profilePic = '${ApiConfig.baseUrlImage}/$profilePic';
        }
      }
    }
    return PollUser(
      id: (json['id'] ?? '').toString(),
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? json['username'] ?? '',
      profilePictureUrl: profilePic,
    );
  }
}

class UserRank {
  final int optionId;
  final int rank;
  final String? text;
  final String? imageUrl;

  UserRank({
    required this.optionId,
    required this.rank,
    this.text,
    this.imageUrl,
  });

  factory UserRank.fromJson(Map<String, dynamic> json) {
    return UserRank(
      optionId: json['option_id'] ?? 0,
      rank: json['rank'] ?? 0,
      text: json['text'],
      imageUrl: json['image_url'],
    );
  }
}