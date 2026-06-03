# libclash

`libclash` 是一个独立的 Go/gomobile 项目，用于构建基于 mihomo 的 Android 原生核心 AAR。

它把 Go 代码和 mihomo 依赖从 Android Gradle 工程中拆出来，通过 Go Modules 管理 mihomo，并使用 `gomobile bind` 生成 Android 可直接依赖的 AAR。Android 侧调用生成的 Java/Kotlin API，不再需要项目自维护的 C/C++ JNI 胶水代码。

## 产物

构建后生成：

```text
dist/android/libclash.aar
```

AAR 内包含：

- gomobile 生成的 Java API
- `go.Seq` 运行时类
- 多 ABI native library：`armeabi-v7a`、`arm64-v8a`、`x86`、`x86_64`

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
internal/app                Android 回调上下文、应用状态
internal/config             配置下载、校验、覆盖、预处理
internal/delegate           mihomo 初始化、socket hook、进程解析
internal/proxy              本地 HTTP listener
internal/tun                Android TUN listener
internal/tunnel             代理组、provider、流量、连接、暂停状态
scripts/build-android.sh    AAR 构建脚本
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
- `GOMOBILE_TARGET`：gomobile target，默认 `android`
- `GO_TAGS`：Go build tags，默认 `foss,with_gvisor,cmfa`

这台环境可直接使用：

```bash
NDK_HOME=/opt/android-sdk/ndk/27.1.12297006 ./scripts/build-android.sh
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
