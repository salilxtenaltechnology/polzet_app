// models/single_post/single_post_model.dart

class SinglePostModel {
  final int id;
  final String user;
  final String description;
  final String createdAt;
  final List<SinglePostPoll> polls;

  const SinglePostModel({
    required this.id,
    required this.user,
    required this.description,
    required this.createdAt,
    required this.polls,
  });

  factory SinglePostModel.fromJson(Map<String, dynamic> json) {
    return SinglePostModel(
      id: json['id'] as int,
      user: json['user'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      polls:
          (json['polls'] as List<dynamic>?)
              ?.map((e) => SinglePostPoll.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': user,
    'description': description,
    'created_at': createdAt,
    'polls': polls.map((e) => e.toJson()).toList(),
  };

  bool get isImagePoll =>
      polls.isNotEmpty &&
      polls.every((p) => p.options.every((o) => o.image != null));

  bool get isTextPoll =>
      polls.isNotEmpty &&
      polls.every((p) => p.options.every((o) => o.text != null));
}


class SinglePostPoll {
  final int id;
  final String question;
  final int maxOptions;
  final List<SinglePostPollOption> options;
  final String totalVotes;
  final int?
  userVote;

  const SinglePostPoll({
    required this.id,
    required this.question,
    required this.maxOptions,
    required this.options,
    required this.totalVotes,
    this.userVote,
  });

  factory SinglePostPoll.fromJson(Map<String, dynamic> json) {
    return SinglePostPoll(
      id: json['id'] as int,
      question: json['question'] as String? ?? '',
      maxOptions: json['max_options'] as int? ?? 1,
      options:
          (json['options'] as List<dynamic>?)
              ?.map(
                (e) => SinglePostPollOption.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      totalVotes: json['total_votes']?.toString() ?? '0',
      userVote: json['user_vote'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'max_options': maxOptions,
    'options': options.map((e) => e.toJson()).toList(),
    'total_votes': totalVotes,
    'user_vote': userVote,
  };

  bool get hasVoted => userVote != null;
}


class SinglePostPollOption {
  final int id;
  final String? text;
  final SinglePostPollImage? image;
  final String voteCount;
  final double percentage;
  final List<SinglePostVoter> voters;

  const SinglePostPollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.percentage,
    required this.voters,
  });

  factory SinglePostPollOption.fromJson(Map<String, dynamic> json) {
    return SinglePostPollOption(
      id: json['id'] as int,
      text: json['text'] as String?,
      image: json['image'] != null
          ? SinglePostPollImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      voteCount: json['vote_count']?.toString() ?? '0',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      voters:
          (json['voters'] as List<dynamic>?)
              ?.map((e) => SinglePostVoter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'image': image?.toJson(),
    'vote_count': voteCount,
    'percentage': percentage,
    'voters': voters.map((e) => e.toJson()).toList(),
  };
}


class SinglePostPollImage {
  final int id;
  final int order;
  final String url;
  final String thumbnailUrl;

  const SinglePostPollImage({
    required this.id,
    required this.order,
    required this.url,
    required this.thumbnailUrl,
  });

  factory SinglePostPollImage.fromJson(Map<String, dynamic> json) {
    return SinglePostPollImage(
      id: json['id'] as int,
      order: json['order'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'url': url,
    'thumbnail_url': thumbnailUrl,
  };

  String resolvedUrl(String baseUrl) {
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }

  String resolvedThumbnailUrl(String baseUrl) {
    if (thumbnailUrl.startsWith('http')) return thumbnailUrl;
    return '$baseUrl$thumbnailUrl';
  }
}


class SinglePostVoter {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? profilePictureUrl;

  const SinglePostVoter({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.profilePictureUrl,
  });

  factory SinglePostVoter.fromJson(Map<String, dynamic> json) {
    return SinglePostVoter(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'first_name': firstName,
    'last_name': lastName,
    'profile_picture_url': profilePictureUrl,
  };

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }
}
