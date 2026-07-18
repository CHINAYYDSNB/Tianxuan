# Tianxuan CI/CD 配置

## GitHub Actions 自动构建

推送到 `main`/`master` 分支时自动触发，构建 release APK。

### Secrets 配置

已在仓库 `CHINAYYDSNB/Tianxuan` 设置以下 4 个 Secrets：

| Secret | 值 |
|---|---|
| `KEYSTORE_BASE64` | keystore 文件的 base64 编码 |
| `KEYSTORE_PASSWORD` | `Tianxuan2026!` |
| `KEY_ALIAS` | `tianxuan` |
| `KEY_PASSWORD` | `Tianxuan2026!` |

### Keystore 信息

- **文件位置**：`android/app/tianxuan.keystore`（已 gitignore，不提交到仓库）
- **别名 (alias)**：`tianxuan`
- **密码**：`Tianxuan2026!`
- **有效期**：10000 天（约 27 年）
- **算法**：RSA 2048 位
- **证书主体**：CN=Tianxuan, OU=Dev, O=Tianxuan, L=Shenzhen, ST=Guangdong, C=CN

> ⚠️ **不要在仓库中共享 keystore 文件和密码！** keystore 已在 `.gitignore` 中排除。本地文件路径：`android/app/tianxuan.keystore`

### 工作流文件

`.github/workflows/build.yml` — 构建流程：
1. Checkout 代码
2. 安装 Java 17 + Flutter
3. `flutter pub get`
4. `dart run build_runner build` 生成代码（riverpod + json_serializable）
5. 从 Secrets 解码 keystore，写入 `android/app/key.properties`
6. `flutter build apk --release`
7. 上传 APK artifact

### 触发条件
- Push 到 `main` 或 `master` 分支
- Pull Request 到 `main` 或 `master` 分支
- 手动触发（workflow_dispatch）

### 未配置 Secrets 时的回退
若 GitHub Secrets 未配置，`key.properties` 不会被创建，Gradle 回退到 debug 签名，构建仍能完成（但产出的是 debug-signed APK）。

---

## 本地构建

```bash
# 生成代码
dart run build_runner build --delete-conflicting-outputs

# Debug APK
flutter build apk --debug

# Release APK（自动读取 android/app/key.properties，若存在则用 release 签名）
flutter build apk --release
```

---

## 如果 keystore 丢失

重新生成（注意：新 keystore 和旧的不一样，Google Play 上架后不能换签名）：

```bash
keytool -genkey -v -keystore android/app/tianxuan.keystore -alias tianxuan \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass Tianxuan2026! -keypass Tianxuan2026! \
  -dname "CN=Tianxuan, OU=Dev, O=Tianxuan, L=Shenzhen, ST=Guangdong, C=CN"

# 更新 GitHub Secret
base64 -w0 android/app/tianxuan.keystore | gh secret set KEYSTORE_BASE64 -R CHINAYYDSNB/Tianxuan
```
