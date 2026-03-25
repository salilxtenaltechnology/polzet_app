class PublicPostsResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<PublicPostItem> results;

  PublicPostsResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PublicPostsResponse.fromJson(Map<String, dynamic> json) {
    return PublicPostsResponse(
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previous'],
      results:
          (json['results'] as List<dynamic>?)
              ?.map((e) => PublicPostItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PublicPostItem {
  final int id;
  final String user;
  final String description;
  final String createdAt;
  final List<PublicPostPoll> polls;
  final List<dynamic> comments;
  final int likesCount;
  final bool isLiked;
  final bool isPolledByCurrentUser;

  PublicPostItem({
    required this.id,
    required this.user,
    required this.description,
    required this.createdAt,
    required this.polls,
    required this.comments,
    required this.likesCount,
    required this.isLiked,
    required this.isPolledByCurrentUser,
  });

  factory PublicPostItem.fromJson(Map<String, dynamic> json) {
    return PublicPostItem(
      id: json['id'] ?? 0,
      user: json['user'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
      polls:
          (json['polls'] as List<dynamic>?)
              ?.map((e) => PublicPostPoll.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      comments: json['comments'] ?? [],
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isPolledByCurrentUser: json['is_polled_by_current_user'] ?? false,
    );
  }
}

class PublicPostPoll {
  final int id;
  final String question;
  final int maxOptions;
  final List<PublicPostPollOption> options;
  final String totalVotes;
  final int? userVote;

  PublicPostPoll({
    required this.id,
    required this.question,
    required this.maxOptions,
    required this.options,
    required this.totalVotes,
    this.userVote,
  });

  factory PublicPostPoll.fromJson(Map<String, dynamic> json) {
    return PublicPostPoll(
      id: json['id'] ?? 0,
      question: json['question'] ?? '',
      maxOptions: json['max_options'] ?? 0,
      options:
          (json['options'] as List<dynamic>?)
              ?.map(
                (e) => PublicPostPollOption.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      totalVotes: json['total_votes']?.toString() ?? '0',
      userVote: json['user_vote'],
    );
  }
}

class PublicPostPollOption {
  final int id;
  final String? text;
  final PublicPostImage? image; 
  final String voteCount;
  final double percentage;
  final List<PublicPostVoter> voters;

  PublicPostPollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.percentage,
    required this.voters,
  });

  factory PublicPostPollOption.fromJson(Map<String, dynamic> json) {
    return PublicPostPollOption(
      id: json['id'] ?? 0,
      text: json['text'],
      image: json['image'] != null
          ? PublicPostImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      voteCount: json['vote_count']?.toString() ?? '0',
      percentage: (json['percentage'] ?? 0).toDouble(),
      voters:
          (json['voters'] as List<dynamic>?)
              ?.map((e) => PublicPostVoter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// Add this new class
class PublicPostImage {
  final int id;
  final String url;

  PublicPostImage({required this.id, required this.url});

  factory PublicPostImage.fromJson(Map<String, dynamic> json) {
    return PublicPostImage(
      id: json['id'] ?? 0,
      url: json['url'] ?? json['image'] ?? '',
    );
  }
}

class PublicPostVoter {
  final int id;
  final String username;
  final String firstName;
  final String lastName;

  PublicPostVoter({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
  });

  factory PublicPostVoter.fromJson(Map<String, dynamic> json) {
    return PublicPostVoter(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
    );
  }
}
