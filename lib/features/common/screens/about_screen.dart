import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _appName = 'Poker Manager';
  String _copyright = '© 2026 Poker Manager Team';

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
        _appName = info.appName;
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
              _appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Version: ${_version.isNotEmpty ? _version : 'Loading...'}'),
            const SizedBox(height: 16),
            const Text(
              'Poker Manager helps you organize, track, and enjoy your poker nights with friends. Manage groups, schedule games, track stats, and more!\n',
            ),
            const SizedBox(height: 16),
            Text(_copyright),
            const SizedBox(height: 8),
            const Text('Developed by the Poker Manager Team.'),
          ],
        ),
      ),
    );
  }
}
