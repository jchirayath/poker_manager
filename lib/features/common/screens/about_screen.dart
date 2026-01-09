import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_constants.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = info.version;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Version: ${_version.isNotEmpty ? _version : 'Loading...'}'),
            const SizedBox(height: 16),
            Text(
              '${AppConstants.appName} helps you organize, track, and enjoy your poker nights with friends. Manage groups, schedule games, track stats, and more!\n',
            ),
            const SizedBox(height: 16),
            Text(AppConstants.copyright),
            const SizedBox(height: 8),
            Text('Developed by ${AppConstants.companyName}.'),
          ],
        ),
      ),
    );
  }
}
