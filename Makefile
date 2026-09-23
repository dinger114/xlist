.PHONY: build build-watch gen splash icons release-android release-aab help

all: build

build:
	dart run build_runner build

build-watch:
	dart run build_runner watch

gen:
	fluttergen

splash:
	dart run flutter_native_splash:create

icons:
	dart run flutter_launcher_icons

# Android 构建需要 JDK 17：
#  - AGP 9 的 JdkImageTransform 要用 JDK 的 jlink 处理 core-for-system-modules.jar，
#    本机 PATH 上的 java 若是 26 会直接失败（--disable-plugin system-modules）。
#  - 用 /usr/libexec/java_home -v 17 解析而不是写死 /opt/homebrew/... 绝对路径，
#    这样 intel mac / Linux 上只要能解析到 17 就能用。
# 解析不到时不要覆盖 JAVA_HOME，让 Gradle 用它自己的默认 JVM、由构建报错暴露问题，
# 而不是在这里静默绑一个错的 JDK。
ifeq ($(shell uname),Darwin)
JDK17 := $(shell /usr/libexec/java_home -v 17 2>/dev/null)
ifneq ($(JDK17),)
export JAVA_HOME := $(JDK17)
endif
endif

# 只出 arm64-v8a 单包（abiFilters 见 android/app/build.gradle）。
# -Pdisable-abi-filtering=true 是必需的：Flutter Gradle Plugin 默认会用
# PLATFORM_ABI_LIST 覆盖我们在 build.gradle 里设的 abiFilters，加上这个
# property 才会尊重工程自己的配置。
release-android:
	flutter build apk \
		--tree-shake-icons \
		--release \
		-Pdisable-abi-filtering=true \
		--obfuscate --split-debug-info=./symbols

release-aab:
	flutter build appbundle \
		--tree-shake-icons \
		--release \
		-Pdisable-abi-filtering=true \
		--obfuscate --split-debug-info=./symbols

help:
	@echo "make build: run build_runner build"
	@echo "make build-watch: run build_runner watch"
	@echo "make gen: generate fluttergen"
	@echo "make json-models: generate json models"
	@echo "make splash: generate splash screen"
	@echo "make icons: generate app icons"
	@echo "make release-android: build release apk (arm64-v8a only)"
	@echo "make release-aab: build release aab (arm64-v8a only)"
