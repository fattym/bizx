import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class GithubRelease {
  final String tagName;
  final String name;
  final String htmlUrl;
  final String? apkDownloadUrl;
  final String publishedAt;

  GithubRelease({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    this.apkDownloadUrl,
    required this.publishedAt,
  });

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] as List<dynamic>? ?? [];
    final apkAsset = assets.firstWhere(
      (a) => (a['name'] as String).toLowerCase().endsWith('.apk'),
      orElse: () => null,
    );

    return GithubRelease(
      tagName: json['tag_name'] as String,
      name: json['name'] as String,
      htmlUrl: json['html_url'] as String,
      apkDownloadUrl: apkAsset != null ? apkAsset['browser_download_url'] as String : null,
      publishedAt: json['published_at'] as String,
    );
  }
}

class GithubReleaseService {
  final String owner;
  final String repo;

  GithubReleaseService({required this.owner, required this.repo});

  static const _baseUrl = 'https://api.github.com';

  Future<GithubRelease?> fetchLatestRelease() async {
    final uri = Uri.parse('$_baseUrl/repos/$owner/$repo/releases/latest');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'dehus-app',
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GithubRelease.fromJson(data);
  }

  Future<bool> isUpdateAvailable() async {
    final latest = await fetchLatestRelease();
    if (latest == null) return false;

    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    final latestVersion = latest.tagName.replaceFirst(RegExp(r'^v'), '');

    return _compareVersions(latestVersion, currentVersion) > 0;
  }

  int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.parse).toList();
    final partsB = b.split('.').map(int.parse).toList();

    for (var i = 0; i < partsA.length && i < partsB.length; i++) {
      if (partsA[i] > partsB[i]) return 1;
      if (partsA[i] < partsB[i]) return -1;
    }

    if (partsA.length > partsB.length) {
      final diff = partsA.sublist(partsB.length);
      if (diff.any((v) => v > 0)) return 1;
    } else if (partsB.length > partsA.length) {
      final diff = partsB.sublist(partsA.length);
      if (diff.any((v) => v > 0)) return -1;
    }

    return 0;
  }
}
