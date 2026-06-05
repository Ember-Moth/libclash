# libclash

`libclash` 是一个独立的 Go 项目，用于构建基于 mihomo 的移动端原生核心。

它把 Go 代码和 mihomo 依赖从客户端工程中拆出来，通过 Go Modules 管理 mihomo。当前支持三种产物：

- `gomobile bind` 生成的 Android AAR
- `go build -buildmode=c-shared` 生成的 Android `libclash.so`
- `go build -buildmode=c-archive` 生成的 iOS `libclash.a` / `libclash.xcframework`

Avalonia/.NET Android 客户端优先使用 C shared 产物，通过 P/Invoke 直接加载 `libclash.so`，不需要项目自维护的 C/C++ JNI 胶水代码。

## 产物

构建后生成：

```text
dist/android/libclash.aar
dist/cshared/android/<abi>/libclash.so
dist/cshared/ios/libclash.xcframework
dist/cshared/ios/iphoneos-arm64/libclash.a
dist/cshared/ios/iphonesimulator/libclash.a
```

AAR 内包含：

- gomobile 生成的 Java API
- `go.Seq` 运行时类
- 多 ABI native library：`armeabi-v7a`、`arm64-v8a`、`x86_64`

默认 Java 包名：

```text
com.github.embermoth.libclash
```

主入口类：

```text
com.github.embermoth.libclash.Libclash
```

## 目录结构

```text
libclash.go                 gomobile 可绑定 API
cmd/main.go                 C shared 导出 API
internal/app                Android 回调上下文、应用状态
internal/config             配置下载、校验、覆盖、预处理
internal/delegate           mihomo 初始化、socket hook、进程解析
internal/proxy              本地 HTTP listener
internal/tun                Android TUN listener
internal/tunnel             代理组、provider、流量、连接、暂停状态
scripts/build-android.sh    AAR 构建脚本
scripts/build-cshared-android.sh
                            Android C shared 构建脚本
scripts/build-carchive-ios.sh
                            iOS C archive/XCFramework 构建脚本
.github/workflows/build-ios.yml
                            iOS native artifact 构建 workflow
docs/usage.md               构建与 Android 接入说明
docs/api.md                 API 与 JSON 结构说明
```

## 快速构建

需要 Go、gomobile、Android SDK 和 Android NDK。

```bash
cd /root/mihomo/libclash
./scripts/build-android.sh
```

脚本读取以下环境变量：

- `ANDROID_NDK_HOME` 或 `NDK_HOME`：NDK 路径，必需
- `ANDROID_API_LEVEL`：Android API level，默认 `21`
- `JAVA_PKG`：生成 Java 包名前缀，默认 `com.github.embermoth`
- `AAR_NAME`：输出 AAR 文件名，默认 `libclash.aar`
- `GOMOBILE_TARGET`：gomobile target，默认 `android/arm,android/arm64,android/amd64`
- `GO_TAGS`：Go build tags，默认 `foss,with_gvisor,cmfa`
- `STRIP_SO`：是否 strip AAR 内的 `.so`，默认 `1`；调试符号构建可设为 `0`
- `STRIP_TOOL`：自定义 strip 工具路径，默认使用 NDK toolchain 的 `llvm-strip`

这台环境可直接使用：

```bash
NDK_HOME=/opt/android-sdk/ndk/27.1.12297006 ./scripts/build-android.sh
```

## 构建 C shared

Avalonia Android 项目使用这个产物：

```bash
cd /root/mihomo/libclash
ANDROID_NDK_HOME=/opt/android-sdk/ndk/29.0.14206865 \
INSTALL_DIR=/root/mihomo/Aureline/Aureline.Android/NativeLibraries \
./scripts/build-cshared-android.sh
```

脚本默认构建以下 ABI，不包含 i386/x86：

```text
armeabi-v7a
arm64-v8a
x86_64
```

构建完成后会执行 `llvm-strip --strip-unneeded`。输出位置：

```text
dist/cshared/android/armeabi-v7a/libclash.so
dist/cshared/android/arm64-v8a/libclash.so
dist/cshared/android/x86_64/libclash.so
dist/cshared/android/include/libclash.h
```

如果设置 `INSTALL_DIR`，脚本会把各 ABI 的 `libclash.so` 复制到对应目录。

## 构建 iOS C archive

iOS 构建需要 macOS + Xcode。本机 Linux/WSL 不构建 iOS，发布产物由 GitHub
Actions 生成：

```text
.github/workflows/build-ios.yml
```

在 macOS 环境手动构建：

```bash
cd /root/mihomo/libclash
./scripts/build-carchive-ios.sh
```

输出位置：

```text
dist/cshared/ios/iphoneos-arm64/libclash.a
dist/cshared/ios/iphonesimulator/libclash.a
dist/cshared/ios/include/libclash.h
dist/cshared/ios/libclash.xcframework
```

GitHub artifact 名称：

```text
libclash-ios
```

## 文档

- [使用文档](docs/usage.md)
- [API 文档](docs/api.md)

## 依赖策略

mihomo 作为普通 Go Module 引入：

```text
github.com/metacubex/mihomo v1.19.26
```

发布构建建议固定到明确版本或具体 commit：

```bash
go get github.com/metacubex/mihomo@<commit>
go mod tidy
```

不要在发布产物中使用浮动分支或本地 `replace`，这样才能保证 native core 可复现。
