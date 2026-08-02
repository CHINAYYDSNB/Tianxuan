import 'package:flutter/material.dart';
import '../../models/website.dart';

/// 网站各配置弹层入口。
/// 具体实现见各阶段（D）逐步填充。

void openDomainSheet(BuildContext context, int websiteId, String title) {
  _showNotImplemented(context, '域名管理');
}

void openIndexSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '默认文档');
}

void openLimitSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '流量限制');
}

void openOtherSheet(BuildContext context, Website website) {
  _showNotImplemented(context, '基础信息');
}

void openProxySheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '反向代理');
}

void openAuthSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '密码访问');
}

void openCorsSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '跨域 CORS');
}

void openHttpsSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, 'HTTPS');
}

void openRealIpSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '真实 IP');
}

void openRewriteSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '伪静态');
}

void openLeechSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '防盗链');
}

void openRedirectSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '重定向');
}

void openPhpSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, 'PHP 版本');
}

void openResourceSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '关联资源');
}

void openLogSheet(
  BuildContext context,
  int websiteId, {
  String? accessLogPath,
  String? errorLogPath,
  String? sitePath,
}) {
  _showNotImplemented(context, '日志查看');
}

void openConfigSheet(BuildContext context, int websiteId) {
  _showNotImplemented(context, '配置文件');
}

void _showNotImplemented(BuildContext context, String name) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$name 功能开发中')));
}
