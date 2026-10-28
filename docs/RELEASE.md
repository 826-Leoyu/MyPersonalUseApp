# 打包 release 版本

## Windows

在 Windows 一侧的仓库根目录（PowerShell）：

```powershell
flutter build windows --release
Remove-Item build\windows\x64\runner\Release\native_assets.json -ErrorAction Ignore
dart run tool/release_check/check_release.dart build\windows\x64\runner\Release
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath build\dailynote-windows-<版本号>.zip -Force
```

zip 里是整个 `Release` 目录的内容（exe、dll、`data\`），解压到任何地方都能直接运行 `Dailynote.exe`。

`native_assets.json` 是打包工具留下的，里面写着仓库的绝对路径。App 运行时读的是 `data\flutter_assets\NativeAssetsManifest.json`（相对路径），所以删掉它不影响运行。

### 检查（M-41）

`check_release.dart` 在 release 目录的所有文件里找开发电脑的痕迹（UTF-8 和 UTF-16，不分大小写，`\`、`/` 和 JSON 转义的 `\\` 都算），找到就列出来并以退出码 1 结束。要找的字符串在运行时从本机收集，不写进仓库：

| 痕迹 | 来源 |
|---|---|
| 用户名、用户目录、OneDrive 目录、pub 缓存 | 环境变量 `USERNAME`、`USERPROFILE`、`OneDrive*`、`PUB_CACHE` |
| Flutter SDK 目录 | 运行脚本的 `dart` 所在位置 |
| git 邮箱 | `git config user.email` |
| 凭据 | `android/key.properties` 里的密码，环境变量 `ANTHROPIC_API_KEY`、`CLAUDE_CODE_OAUTH_TOKEN`（报告里不显示内容） |
| 测试邮箱、OneDrive 账号 | 本地清单 `tool/release_check/local_traces.txt` |

本地清单不进仓库，第一次要自己建，一行一个，`#` 开头是注释。没有这个文件时脚本不检查，直接退出。OneDrive 账号可以这样查：

```powershell
reg query HKCU\Software\Microsoft\OneDrive\Accounts /s /v UserEmail
```

查不出来、也不用查的：

- `data\app.so` 里的 `file:///<仓库路径>/.dart_tool/flutter_build/dart_plugin_registrant.dart`：Flutter 编译时写进去的，只用在报错信息里，运行时不会去打开。仓库放在用户目录下时，这一条会被当成用户目录查出来，所以仓库不要放在 `C:\Users\<用户名>` 下面。
- 电脑名：常常是一个普通单词，在 dll 里到处都是。
- `flutter_windows.dll` 里的 `C:\b\s\w\...`：Flutter 官方构建机的路径。

## Android

### 第一次：生成 keystore

keystore 放在**仓库外**，并且要自己备份。丢了以后就没法给已经装好的 App 推更新，只能卸载重装，数据也会跟着丢。

```powershell
keytool -genkeypair -v -keystore D:\keys\dailycanvas.jks -keyalg RSA -keysize 2048 -validity 10000 -alias dailycanvas
```

然后新建 `android/key.properties`（已在 `.gitignore` 里，不会进仓库）：

```properties
storePassword=<keystore 密码>
keyPassword=<key 密码>
keyAlias=dailycanvas
storeFile=D:/keys/dailycanvas.jks
```

没有这个文件时 release 构建会直接失败，不会退回 debug 签名。debug 构建不受影响。

### 构建并安装

```powershell
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

### 检查（AC-39）

`test/release/offline_test.dart` 在 CI 里检查主 manifest 和 `lib/` 的源码。插件在 manifest 合并时带进来的权限只能看打出来的 APK：

```powershell
<Android SDK>\build-tools\<版本>\aapt.exe dump permissions build\app\outputs\flutter-apk\app-release.apk
<Android SDK>\build-tools\<版本>\apksigner.bat verify --print-certs build\app\outputs\flutter-apk\app-release.apk
```

第一条的输出里不应该有 `android.permission.INTERNET`。第二条的证书应该是自己的 keystore，不是 `CN=Android Debug`。
