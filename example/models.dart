class Root {
  final int code;
  final String message;
  final Tweet tweet;

  Root({
    required this.code,
    required this.message,
    required this.tweet,
  });

  Root.fromJson(Map<String, dynamic> json) : code = json['code'], message = json['message'], tweet = Tweet.fromJson(json['tweet']);
}

class Tweet {
  final Author author;
  final int bookmarks;
  final dynamic color;
  final dynamic communityNote;
  final String createdAt;
  final int createdTimestamp;
  final String id;
  final bool isNoteTweet;
  final String lang;
  final int likes;
  final Media media;
  final bool possiblySensitive;
  final String provider;
  final RawText rawText;
  final int replies;
  final dynamic replyingTo;
  final dynamic replyingToStatus;
  final int retweets;
  final String source;
  final String text;
  final String twitterCard;
  final String url;
  final int views;

  Tweet({
    required this.author,
    required this.bookmarks,
    required this.color,
    required this.communityNote,
    required this.createdAt,
    required this.createdTimestamp,
    required this.id,
    required this.isNoteTweet,
    required this.lang,
    required this.likes,
    required this.media,
    required this.possiblySensitive,
    required this.provider,
    required this.rawText,
    required this.replies,
    required this.replyingTo,
    required this.replyingToStatus,
    required this.retweets,
    required this.source,
    required this.text,
    required this.twitterCard,
    required this.url,
    required this.views,
  });

  Tweet.fromJson(Map<String, dynamic> json)
    : author = Author.fromJson(json['author']),
      bookmarks = json['bookmarks'],
      color = json['color'],
      communityNote = json['community_note'],
      createdAt = json['created_at'],
      createdTimestamp = json['created_timestamp'],
      id = json['id'],
      isNoteTweet = json['is_note_tweet'],
      lang = json['lang'],
      likes = json['likes'],
      media = Media.fromJson(json['media']),
      possiblySensitive = json['possibly_sensitive'],
      provider = json['provider'],
      rawText = RawText.fromJson(json['raw_text']),
      replies = json['replies'],
      replyingTo = json['replying_to'],
      replyingToStatus = json['replying_to_status'],
      retweets = json['retweets'],
      source = json['source'],
      text = json['text'],
      twitterCard = json['twitter_card'],
      url = json['url'],
      views = json['views'];
}

class Author {
  final dynamic avatarColor;
  final String avatarUrl;
  final String bannerUrl;
  final String description;
  final int followers;
  final int following;
  final String id;
  final String joined;
  final int likes;
  final String location;
  final int mediaCount;
  final String name;
  final bool protected;
  final String screenName;
  final int tweets;
  final String url;
  final Website website;

  Author({
    required this.avatarColor,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.description,
    required this.followers,
    required this.following,
    required this.id,
    required this.joined,
    required this.likes,
    required this.location,
    required this.mediaCount,
    required this.name,
    required this.protected,
    required this.screenName,
    required this.tweets,
    required this.url,
    required this.website,
  });

  Author.fromJson(Map<String, dynamic> json)
    : avatarColor = json['avatar_color'],
      avatarUrl = json['avatar_url'],
      bannerUrl = json['banner_url'],
      description = json['description'],
      followers = json['followers'],
      following = json['following'],
      id = json['id'],
      joined = json['joined'],
      likes = json['likes'],
      location = json['location'],
      mediaCount = json['media_count'],
      name = json['name'],
      protected = json['protected'],
      screenName = json['screen_name'],
      tweets = json['tweets'],
      url = json['url'],
      website = Website.fromJson(json['website']);
}

class Website {
  final String displayUrl;
  final String url;

  Website({
    required this.displayUrl,
    required this.url,
  });

  Website.fromJson(Map<String, dynamic> json) : displayUrl = json['display_url'], url = json['url'];
}

class Media {
  final List<All> all;
  final List<All> photos;

  Media({
    required this.all,
    required this.photos,
  });

  Media.fromJson(Map<String, dynamic> json)
    : all = (json['all'] as List).map((e) => All.fromJson(e as Map<String, dynamic>)).toList(),
      photos = (json['photos'] as List).map((e) => All.fromJson(e as Map<String, dynamic>)).toList();
}

class All {
  final int height;
  final String type;
  final String url;
  final int width;

  All({
    required this.height,
    required this.type,
    required this.url,
    required this.width,
  });

  All.fromJson(Map<String, dynamic> json) : height = json['height'], type = json['type'], url = json['url'], width = json['width'];
}

class RawText {
  final List<Facet> facets;
  final String text;

  RawText({
    required this.facets,
    required this.text,
  });

  RawText.fromJson(Map<String, dynamic> json)
    : facets = (json['facets'] as List).map((e) => Facet.fromJson(e as Map<String, dynamic>)).toList(),
      text = json['text'];
}

class Facet {
  final List<int> indices;
  final String original;
  final String type;
  final String? display;
  final String? id;
  final String? replacement;

  Facet({
    required this.indices,
    required this.original,
    required this.type,
    this.display,
    this.id,
    this.replacement,
  });

  Facet.fromJson(Map<String, dynamic> json)
    : indices = (json['indices'] as List).map((i) => i as int).toList(),
      original = json['original'],
      type = json['type'],
      display = json['display'],
      id = json['id'],
      replacement = json['replacement'];
}
