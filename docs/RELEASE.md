# 打包 release 版本

## Windows

在 Windows 一侧的仓库根目录（PowerShell）：

```powershell
flutter build windows --release
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath build\dailynote-windows-<版本号>.zip -Force
```

zip 里是整个 `Release` 目录的内容（exe、dll、`data\`），解压到任何地方都能直接运行 `Dailynote.exe`。

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
