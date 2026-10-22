<table>
  <tr>
    <td width="20%">
      <img src="assets/icon/app/round.png"/>
    </td>
    <td width="80%">
      <h1>e1547 · 简体中文版</h1>
      <h4>A sophisticated e621 browser — 非官方汉化构建</h4>
      <a href="blob/zh-cn/LICENSE"><img src="https://img.shields.io/github/license/clynamic/e1547"></a>
      <a href="https://github.com/A-great-show/e1547/actions/workflows/build-zh-apk.yml"><img src="https://img.shields.io/badge/auto%20build-Actions-blue"></a>
    </td>
  </tr>
</table>

> ## ⚠️ 这是修改版，不是官方版本
>
> 本仓库 fork 自 [**clynamic/e1547**](https://github.com/clynamic/e1547)（作者 [clragon](https://github.com/clragon)），
> 并在此基础上做了如下修改（依 GPL-3.0 §5(a) 的醒目声明要求）：
>
> | 项目 | 内容 |
> | --- | --- |
> | 修改日期 | 2026-10-22 |
> | 修改者 | [A-great-show](https://github.com/A-great-show)（与原作者无关） |
> | 修改内容 | 1. 界面文案简体中文化（构建期字符串补丁）<br>2. 应用内固定使用 `zh_CN` locale，Material / Cupertino 组件、日期时间选择器、文本选择菜单随之中文 |
> | 修改位置 | 汉化相关文件全部位于 `tool/l10n/` 与 `lib/app/widget/app.dart`，其余源码保持上游原样 |
>
> **本项目与原作者 clragon 无关，未获得其背书。** 所有代码功劳归于原作者与所有上游贡献者。
> 若你要使用稳定、受支持的版本，请前往 [官方仓库](https://github.com/clynamic/e1547)。

---

## 下载

汉化版 APK（arm64-v8a / armeabi-v7a / universal）发布在：

👉 **https://github.com/A-great-show/e1547/releases/tag/zh-cn-latest**

同一 Release 还附带：

- `e1547-zh-cn-source.tar.gz` —— **打完汉化补丁后的完整对应源码**（GPL-3.0 §6 要求）
- `LICENSE` —— GNU GPL v3.0 许可证全文

### 安装说明

- 本 APK 使用 **debug 签名**（仓库中没有配置 release 密钥），与 Google Play / 官方 Releases 的签名**不同**。
  手机里已有官方版本时，请**先卸载官方版**再安装，否则会提示「应用未安装」。
- 因此**不要**拿官方公布在 README 里的证书指纹来校验本 APK，指纹必然不一致 —— 那是官方包的指纹，不是本包的。
- 首次启动时若系统语言非中文也不影响：本构建在检测到本地化委托支持中文后会固定使用简体中文。

## 汉化是怎么做的

上游项目没有 i18n 框架，界面文字全部硬编码在 Dart 源码里。为了让这个 fork 能继续干净地跟随上游更新，
汉化没有逐行改动源码，而是采用**构建期打补丁**：

```
tool/l10n/
├── zh_cn.json        # 词典：英文原文 → 中文（键名与源码引号内内容逐字符一致）
├── zh_cn_2.json      # 后续批次词条，脚本会自动合并所有 zh_cn*.json
├── apply_zh.py       # 在 flutter build 之前重写 lib/**/*.dart 中的字符串字面量
├── extract_strings.py# 提取「尚未翻译」的字面量，供下一批补词条
├── extracted.txt     # 上面工具的输出（由 CI 自动提交）
└── README.md         # 方案细节与安全策略
```

- 补丁脚本只替换**单词字面量**，并跳过生成文件、注释、含转义的字面量、Map 的 key，以及涉及路由 / 请求参数 / Header / 存储 key 的行，
  避免把接口参数翻成中文导致请求失败。
- 支持 `${...}` / `$var` 插值：词典 key 原样匹配，译文里可以自由调整语序。
- 想补词条：在源码里找到英文（例如 `Text('Comments')`），在 `zh_cn*.json` 里加 `"Comments": "评论"`，推到 `zh-cn` 分支即可，Actions 会自动重新打包。

### 本地复现（任何人可验证构建产物与源码一致）

```bash
git clone https://github.com/A-great-show/e1547 -b zh-cn
cd e1547
flutter pub get
python3 tool/l10n/apply_zh.py      # 应用汉化补丁，源码即与发布 APK 对应
flutter build apk --release        # 产物：build/app/outputs/apk/release/*.apk
```

## 许可证与 GPL-3.0 合规

本项目与原项目一样，以 **GNU General Public License v3.0** 发布，全文见 [LICENSE](LICENSE)。
本仓库的**修改部分同样以 GPL-3.0 授权**。合规要点：

- **修改声明**（§5(a)）：见本文开头的修改说明表格，构成醒目声明。
- **对应源码**（§6）：发布的二进制（APK）与其对应源码同时提供 —— 仓库 `zh-cn` 分支即完整源码，
  且每个 Release 附带 `e1547-zh-cn-source.tar.gz`（已应用补丁的源码树），访问方式与二进制相同（同一个 Release 页面）。
- **构建/安装脚本**（§6 关于「用于控制目标码编译与安装的脚本」）：`tool/l10n/*.py`、`.github/workflows/build-zh-apk.yml`、
  `pubspec.yaml`、`android/` 等全部包含在上述源码包内。
- **无附加限制**：本仓库未添加任何 GPL-3.0 之外的条款（例如不限制商用、不收取额外许可费）；
  如果你再分发本构建，请同样遵守 GPL-3.0。
- **商标与署名**：`e1547` 名称、图标与作者署名权利归原作者；GPL-3.0 不授予商标许可，
  本仓库仅在说明来源与血缘时使用该名称，且已明确标注「非官方修改版」。

---

## Features

- Crossplatform (Android, iOS)
- Browse posts and pools
- Edit posts
- Comment on posts
- Download Images
- Favorite, Up and down vote posts
- Follow tags with notifications
- Local blacklist
- DText parsing
- Video support
- Multiple logins
- Multiple App Themes

## Screenshots

<p align="center">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/1_en-US.png" width="30%">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/2_en-US.png" width="30%">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/3_en-US.png" width="30%">
</p>

## Compilation

标准上游构建方式：

1. 安装 [Flutter](https://flutter.dev/docs/get-started/install)
2. `flutter pub get`
3. `flutter build apk`（汉化构建需先执行 `python3 tool/l10n/apply_zh.py`）

CI 构建流程见 [`.github/workflows/build-zh-apk.yml`](.github/workflows/build-zh-apk.yml)。

## Credit

[<img src="https://github.com/clragon.png" width="100px;"/>](https://github.com/clragon)

原作者 [clragon](https://github.com/clragon) 编写了（绝大部分）代码，这是一个热情驱动的项目。
本项目只是在其基础上叠加了中文语言补丁，**没有原作者就没有这个 App**。

#### Additional thanks to

- [Miyoyo](https://github.com/miyoyo) for performance optimisations.
- [Perlatus](https://github.com/perlatus) for writing the original code base.

上游社区渠道（提问上游问题时请使用这些，而不是本 fork）：

- Discord: https://discord.gg/MRwKGqfmUz
- 论坛帖: https://e926.net/forum_topics/25854
- 上游 Issues: https://github.com/clynamic/e1547/issues
