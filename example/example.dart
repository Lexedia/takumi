import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:takumi/takumi.dart';

import 'models.dart';

final client = HttpClient();

/// A simple CLI application that converts a tweet to an image.
void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart example/example.dart <tweet_id>');
    exit(1);
  }

  // final tweetId = args[0];

  final takumi = Renderer();

  final request = await client.getUrl(Uri.parse('https://api.fxtwitter.com/0ws0w/status/1996251302771261568'));
  request.headers.set('User-Agent', 'TakumiExample/1.0');
  final response = await request.close();
  final tweetJson = await response.transform(utf8.decoder).join();
  final root = Root.fromJson(json.decode(tweetJson));

  final tweet = root.tweet;

  final tree = buildTree(tweet);
  for (final img in tweet.media.photos) {
    final data = await client.getUrl(Uri.parse(img.url)).then((req) => req.close()).then((res) => res.expand((e) => e).toList());
    takumi.putPersistentImage(img.url, Uint8List.fromList(data));
  }

  final avatarData = await client.getUrl(Uri.parse(tweet.author.avatarUrl)).then((req) => req.close()).then((res) => res.expand((e) => e).toList());
  takumi.putPersistentImage(tweet.author.avatarUrl, Uint8List.fromList(avatarData));

  final image = await takumi.render(tree);

  await File('tweet.png').writeAsBytes(image);
  print('Tweet image saved to tweet.png');
  client.close();
}

Node buildTree(Tweet tweet) {
  return ContainerNode(
    rawStyle: {
      'backgroundColor': 'black',
      'width': '100%',
      'height': '100%',
      'flexDirection': 'column',
      'padding': '3rem',
      'paddingBottom': '0',
    },
    children: [
      ContainerNode(
        rawStyle: {
          'marginBottom': '2rem',
          'gap': '2rem',
          'alignItems': 'center',
        },
        children: [
          ImageNode(
            tweet.author.avatarUrl,
            rawStyle: {
              'width': '120',
              'height': '120',
              'borderRadius': '50%',
            },
          ),
          TextNode(
            tweet.author.name,
            style: .new(
              color: .of(Colour('white')),
              fontWeight: .of('700'),
            ),
          ),
          TextNode(
            '@${tweet.author.screenName}',
            style: .new(
              color: .of(Colour('gray')),
              fontWeight: .of('300'),
            ),
          ),
        ],
      ),
      ContainerNode(
        rawStyle: {
          'marginBottom': '2rem',
        },
        children: [
          _buildTextWithFacets(tweet.rawText),
        ],
      ),
      ContainerNode(
        rawStyle: {
          'width': '100%',
          'flexGrow': '1',
        },
        children: [
          ImageNode(
            tweet.media.photos.first.url,
            rawStyle: {
              'width': "100%",
              'borderRadius': "2rem",
              'borderWidth': '2',
              'borderColor': "dimgray",
            },
          ),
        ],
      ),
    ],
  );
}

Node _buildTextWithFacets(RawText rawText) {
  if (rawText.facets.isEmpty) {
    return TextNode(
      rawText.text,
      style: .new(
        color: .of(Colour('white')),
        fontSize: .of(48),
        fontWeight: .of('400'),
      ),
    );
  }

  final segments = <TextNode>[];
  int lastIndex = 0;

  for (final facet in rawText.facets) {
    final start = facet.indices[0];
    final end = facet.indices[1];

    if (lastIndex < start) {
      segments.add(
        TextNode(
          rawText.text.substring(lastIndex, start),
          style: .new(
            color: .of(Colour('white')),
            fontSize: .of(48),
            fontWeight: .of('400'),
          ),
        ),
      );
    }

    // Add styled facet
    final facetText = rawText.text.substring(start, end);
    segments.add(_buildFacetNode(facet, facetText));

    lastIndex = end;
  }

  // Add remaining text
  if (lastIndex < rawText.text.length) {
    segments.add(
      TextNode(
        rawText.text.substring(lastIndex),
        style: .new(
          color: .of(Colour('white')),
          fontSize: .of(48),
          fontWeight: .of('400'),
        ),
      ),
    );
  }

  return ContainerNode(
    children: segments,
  );
}

TextNode _buildFacetNode(Facet facet, String text) {
  switch (facet.type) {
    case 'hashtag':
      return TextNode(
        text,
        style: .new(
          color: .of(Colour('#1DA1F2')),
          fontWeight: .of('400'),
          fontSize: .of(48),
        ),
      );
    case 'mention':
      return TextNode(
        text,
        style: .new(
          color: .of(Colour('#1DA1F2')),
          fontWeight: .of('400'),
          fontSize: .of(48),
        ),
      );
  }

  return TextNode('');
}
