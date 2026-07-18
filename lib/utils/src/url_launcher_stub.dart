import 'package:url_launcher/url_launcher.dart';

/// Open URL in browser on native (Android/iOS).
void openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
