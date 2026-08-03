import 'package:flutter/material.dart';
import '../../models/website.dart';
import 'website_auth_sheet.dart';
import 'website_config_sheet.dart';
import 'website_cors_sheet.dart';
import 'website_domain_sheet.dart';
import 'website_https_sheet.dart';
import 'website_index_sheet.dart';
import 'website_leech_sheet.dart';
import 'website_limit_sheet.dart';
import 'website_log_sheet.dart';
import 'website_other_sheet.dart';
import 'website_php_sheet.dart';
import 'website_proxy_sheet.dart';
import 'website_real_ip_sheet.dart';
import 'website_redirect_sheet.dart';
import 'website_resource_sheet.dart';
import 'website_rewrite_sheet.dart';
import 'website_ssl_sheet.dart';

/// 网站各配置弹层入口。

void openDomainSheet(BuildContext context, int websiteId, String title) =>
    showDomainSheet(context, websiteId, title);

void openIndexSheet(BuildContext context, int websiteId) =>
    showIndexSheet(context, websiteId);

void openLimitSheet(BuildContext context, int websiteId) =>
    showLimitSheet(context, websiteId);

void openOtherSheet(BuildContext context, Website website) =>
    showOtherSheet(context, website);

void openRealIpSheet(BuildContext context, int websiteId) =>
    showRealIpSheet(context, websiteId);

void openCorsSheet(BuildContext context, int websiteId) =>
    showCorsSheet(context, websiteId);

void openProxySheet(BuildContext context, int websiteId) =>
    showProxySheet(context, websiteId);

void openAuthSheet(BuildContext context, int websiteId) =>
    showAuthSheet(context, websiteId);

void openLeechSheet(BuildContext context, int websiteId) =>
    showLeechSheet(context, websiteId);

void openRewriteSheet(BuildContext context, int websiteId) =>
    showRewriteSheet(context, websiteId);

void openRedirectSheet(BuildContext context, int websiteId) =>
    showRedirectSheet(context, websiteId);

void openPhpSheet(BuildContext context, int websiteId) =>
    showPhpSheet(context, websiteId);

void openResourceSheet(BuildContext context, int websiteId) =>
    showResourceSheet(context, websiteId);

void openHttpsSheet(BuildContext context, int websiteId) =>
    showHttpsSheet(context, websiteId);

/// 独立的 SSL 证书管理
void openSslManageSheet(BuildContext context) => showSslManageSheet(context);

void openLogSheet(
  BuildContext context,
  int websiteId, {
  String? accessLogPath,
  String? errorLogPath,
  String? sitePath,
}) => showLogSheet(
  context,
  websiteId,
  accessLogPath: accessLogPath,
  errorLogPath: errorLogPath,
  sitePath: sitePath,
);

void openConfigSheet(BuildContext context, int websiteId) =>
    showConfigSheet(context, websiteId);
