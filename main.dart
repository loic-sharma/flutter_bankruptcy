import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

void main(List<String> arguments) async {
  String? token = Platform.environment['GITHUB_TOKEN'];
  String? after;

  final issues = <Issue>[];
  for (var i = 0; i < 100; i++) {
    final response = await loadIssues(token, 'flutter', 'flutter', after);

    issues.addAll(response.issues);
    after = response.endCursor;
  }

  final outputFile = File('issues.csv').openWrite();

  outputFile.writeln('issue_url,issue_created_at,issue_closed_at,open_duration_days,has_associated_pr');

  for (final issue in issues) {
    final openDuration = issue.closedAt.difference(issue.createdAt);

    outputFile.write(issue.url);
    outputFile.write(',');
    outputFile.write(issue.createdAt.toUtc().toIso8601String());
    outputFile.write(',');
    outputFile.write(issue.closedAt.toUtc().toIso8601String());
    outputFile.write(',');
    outputFile.write(openDuration.inDays);
    outputFile.write(',');
    outputFile.write(issue.associatedPullRequest != null ? 'true' : 'false');
    outputFile.writeln();
  }

  await outputFile.flush();
  outputFile.close();

  print('');
  print('End cursor:');
  print(after);
  print('');

  print('Done!');
}

Future<Issues> loadIssues(
  String? token,
  String owner,
  String repository,
  String? after,
) async {
  return await _runQuery(
    token: token,
    body: json.encode({
      'query': _issuesQuery,
      'variables': {
        'owner': owner,
        'repository': repository,
        'after': after,
      },
    }),
    resultCallback: Issues.fromJson,
  );
}

Future<T> _runQuery<T>({
  String? token,
  String? body,
  required T Function(Map<String, dynamic>) resultCallback,
}) async {
  final uri = Uri.parse('https://api.github.com/graphql');
  final headers = <String, String>{
    'Accept': 'application/vnd.github+json',
    'X-Request-Type': 'GraphQL',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  for (var attempt = 0; attempt < 3; attempt++) {
    stdout.write('POST $uri...');
    await stdout.flush();

    final timer = Stopwatch()..start();
    final response = await http.post(uri, body: body, headers: headers);

    stdout.writeln(' ${response.statusCode} (${timer.elapsed.inMilliseconds}ms)');

    if (response.statusCode != 200) {
      print('Reason: ${response.reasonPhrase}');
      print('Attempt ${attempt + 1}/3...');
      await Future.delayed(Duration(seconds: 3));
      continue;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return resultCallback(json);
  }

  throw 'Failed to run query in 3 attempts.';
}

const _issuesQuery =
'''
query RecentlyUpdatedClosedIssuesWithPR(\$owner: String!, \$repository: String!, \$after: String) {
  repository(owner: \$owner, name: \$repository) {
    issues(
      first: 20,
      after: \$after,
      states: CLOSED,
      orderBy: { field: UPDATED_AT, direction: DESC }
    ) {
      pageInfo {
        endCursor
        hasNextPage
      }
      edges {
        node {
          url
          title
          createdAt
          closedAt
          timelineItems(itemTypes: [CONNECTED_EVENT, CROSS_REFERENCED_EVENT], first: 1) {
            nodes {
              ... on ConnectedEvent {
                subject {
                  ... on PullRequest {
                    url
                  }
                }
              }
              ... on CrossReferencedEvent {
                source {
                  ... on PullRequest {
                    url
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
''';

class Issues {
  Issues({
    required this.endCursor,
    required this.hasNextPage,
    required this.issues,
  });

  final String endCursor;
  final bool hasNextPage;
  final List<Issue> issues;

  factory Issues.fromJson(Map<String, dynamic> json) {
    final issues = json['data']['repository']['issues'];

    return Issues(
      endCursor: issues['pageInfo']['endCursor'] as String,
      hasNextPage: issues['pageInfo']['hasNextPage'] as bool,
      issues: [
        for (final issue in issues['edges'] as List<dynamic>)
          Issue.fromJson(issue['node'] as Map<String, dynamic>),
      ],
    );
  }
}

class Issue {
  Issue({
    required this.title, 
    required this.url, 
    required this.createdAt, 
    required this.closedAt, 
    required this.associatedPullRequest
  });

  final String title;
  final Uri url;
  final DateTime createdAt;
  final DateTime closedAt;
  final Uri? associatedPullRequest;

  factory Issue.fromJson(Map<String, dynamic> json) {
    final nodes = json['timelineItems']['nodes'] as List<dynamic>;
    final node = nodes.firstOrNull as Map<String, dynamic>?;
    final associatedPullRequest = node?['source']?['url'];

    return Issue(
      title: json['title'] as String,
      url: Uri.parse(json['url'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      closedAt: DateTime.parse(json['closedAt'] as String),
      associatedPullRequest: associatedPullRequest != null ? Uri.parse(associatedPullRequest) : null,
    );
  }
}
