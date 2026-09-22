.PHONY: build help

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

# 只出 arm64-v8a 单包（abiFilters 见 android/app/build.gradle）。
# -Pdisable-abi-filtering=true 是必需的：Flutter Gradle Plugin 默认会用
# PLATFORM_ABI_LIST 覆盖我们在 build.gradle 里设的 abiFilters，加上这个
# property 才会尊重工程自己的配置。
release-android:
	flutter build apk \
		--no-tree-shake-icons \
		--release \
		-Pdisable-abi-filtering=true \
		--obfuscate --split-debug-info=./symbols

release-aab:
	flutter build appbundle \
		--no-tree-shake-icons \
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
