import 'package:flutter/material.dart';
import '../../utils/url_launcher.dart';

class ContributorsPage extends StatelessWidget {
  const ContributorsPage({super.key});

  static const _contributors = [
    _Contributor(
      login: 'Zeyu-vinfya',
      name: 'Vinfya',
      avatarUrl: 'https://avatars.githubusercontent.com/u/219320546?v=4',
      htmlUrl: 'https://github.com/Zeyu-vinfya',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('贡献者')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.favorite, size: 40, color: Colors.red.withAlpha(180)),
                  const SizedBox(height: 12),
                  Text(
                    '除了作者以外，这些开发者也为软件的开发做出了巨大贡献，谢谢你们！',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._contributors.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(c.avatarUrl),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('@${c.login}'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openUrl(c.htmlUrl),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _Contributor {
  final String login;
  final String name;
  final String avatarUrl;
  final String htmlUrl;

  const _Contributor({
    required this.login,
    required this.name,
    required this.avatarUrl,
    required this.htmlUrl,
  });
}
