import 'package:flutter/material.dart';
import '../file/file_list_page.dart';
import '../ssh/ssh_home_page.dart';
import '../docker/docker_home_page.dart';

class ManagementPage extends StatelessWidget {
  const ManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCard(context, Icons.folder_outlined, '文件', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FileListPage()))),
            const SizedBox(height: 12),
            _buildCard(context, Icons.terminal, 'SSH', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SshHomePage()))),
            const SizedBox(height: 12),
            _buildCard(context, Icons.view_in_ar_outlined, '容器', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DockerHomePage()))),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
        onTap: onTap,
      ),
    );
  }
}
