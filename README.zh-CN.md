# aLaunchpad

> 极简、键盘优先的 **macOS 应用启动器** —— 融合 Launchpad 的分页栅格与 Spotlight 的即时搜索，支持**拼音搜索**、归档管理，**待机零 CPU 占用**。纯 Swift / SwiftUI / AppKit 实现，无 Electron、无第三方依赖。

[English](README.md) · [简体中文](README.zh-CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-13.0+-blue.svg)](#%E7%B3%BB%E7%BB%9F%E8%A6%81%E6%B1%82)
[![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-lightgrey.svg)](#%E7%B3%BB%E7%BB%9F%E8%A6%81%E6%B1%82)
[![Release](https://img.shields.io/github/v/release/mu0072/aLaunchpad?include_prereleases)](https://github.com/mu0072/aLaunchpad/releases)
[![Stars](https://img.shields.io/github/stars/mu0072/aLaunchpad?style=social)](https://github.com/mu0072/aLaunchpad/stargazers)

一个免费、开源的 Spotlight / Alfred / Raycast 替代方案，专为只想要**经典 Launchpad 分页栅格 + 出色键盘体验 + 中文拼音搜索**的用户而生。

---

## 目录

- [下载](#下载)
- [快速上手](#快速上手)
- [功能特性](#功能特性)
- [键盘与鼠标](#键盘与鼠标)
- [从源码构建](#从源码构建)
- [项目结构](#项目结构)
- [架构决策](#架构决策)
- [常见问题](#常见问题)
- [已知限制](#已知限制)
- [路线图](#路线图)
- [卸载](#卸载)
- [参与贡献](#参与贡献)
- [开源协议](#开源协议)

---

## 下载

从 [**Releases**](https://github.com/mu0072/aLaunchpad/releases) 页面下载最新的 `aLaunchpad.zip` 或 `aLaunchpad.dmg`，两者内容相同（Apple Silicon + Intel 通用二进制）。

### 首次打开（macOS Gatekeeper 提示）

aLaunchpad 使用 **ad-hoc 自签名**（未经 Apple 公证），首次打开时 macOS 会拦截并提示*"无法验证 aLaunchpad 的开发者"*。允许方法：

1. 双击 app 一次，会被系统拒绝 —— 这是正常的。
2. 打开 **系统设置 → 隐私与安全性**。
3. 滚动到 **安全性** 部分，在 aLaunchpad 提示旁点击 **仍要打开**。
4. 在弹出的对话框里再次确认。之后 app 就能正常打开了。

或者通过终端一键解决：

```bash
xattr -dr com.apple.quarantine /Applications/aLaunchpad.app
```

---

## 快速上手

1. 从 [Releases](https://github.com/mu0072/aLaunchpad/releases) **下载** `aLaunchpad.zip`，解压后把 `aLaunchpad.app` 拖到 `/Applications`。
2. **首次打开一次**（参考上面的 Gatekeeper 说明）。
3. 任意时刻按 **⌥ + Space** 唤起启动器。
4. **直接输入**进行筛选 —— 试试 `wx` 搜 微信，`chrome` 搜 Chrome。
5. **Enter** 启动，**Esc** 收起。

就这么简单。无需账号，无需任何权限授予，无后台守护进程。

---

## 系统要求

- macOS 13 Ventura 或更高
- Apple Silicon（arm64）或 Intel（x86_64）Mac

---

## 功能特性

### 核心
- **扫描所有 macOS 应用来源** —— `/Applications`、`/System/Applications`、`~/Applications`。按 `bundleIdentifier` 去重，路径作为后备。
- **FSEvents 自动刷新** —— 安装或卸载应用约 1 秒内自动重新扫描（FSEventStream 合并延迟）。无需重启或手动点 "重新扫描"。重扫期间若所选应用仍存在，选择状态会被保留。
- **悬浮半透明面板** —— 90% × 90% 居中显示，HUD 毛玻璃质感，10pt 圆角，正确的窗口阴影。
- **经典 Launchpad 分页栅格** —— 固定每页 8 列 × 4 行（32 个应用），底部分页指示点。页数根据可见应用数动态计算，只有一页时不显示指示点。88pt 图标，固定 2 行标签，**行间距根据可用高度动态计算**，搜索栏与指示点之间始终均匀填满。
- **异步扫描** —— 在后台优先级 detached task 中执行，绝不阻塞主线程。
- **图标缓存** —— 按应用路径作 key 的内存 `NSImage` 缓存，滚动间复用。

### 搜索
- **边输边过滤**，打开即自动聚焦输入框。
- **拼音匹配** —— `微信` 可以用 `weixin` 或 `wx` 搜到。底层用 `CFStringTransform(kCFStringTransformMandarinLatin)`，扫描时预计算 token，每次按键只需几次 `String.contains` 检查。
- **子串 + 首字母** —— 全拼（`wei xin`）和首字母（`wx`）都能命中。

### 收藏与归档
- **收藏** 会被推到分页列表最前面，永远占据第一页。
- **归档**（v1.2 新增）—— 鼠标悬停任意应用图标，点击右上角小 `archivebox` 按钮即可移出主栅格。搜索栏右侧的 📦 图标可切换到归档视图（原位切换，同一面板），归档视图中再次点击小按钮即可恢复。已归档的应用仍会在主视图搜索结果中出现，以暗色 + 右上角角标显示，Enter 仍可正常启动。
- v1.1 老用户：旧的 `Hide` 机制已废弃。首次启动时 `aLaunchpad.hidden` 数据会自动迁移到 `aLaunchpad.archived`。
- 所有偏好持久化到 `UserDefaults`，key 前缀为 `aLaunchpad.*`。

### 排序
- **名称（A → Z）** —— 默认
- **名称（Z → A）**
- **添加时间（最新）** —— 用 `URLResourceKey.creationDateKey` 取文件系统创建时间
- **添加时间（最早）**
- 排序选择跨启动保持。

### 窗口行为
- 无边框、不激活的 `NSPanel` 子类，但仍能获得键盘焦点
- HUD 材质（`.hudWindow`）背景模糊 + 25% 暗色叠加
- 浮于所有 Space 与全屏应用之上
- 10pt 圆角，与 macOS 标准缩放窗口一致
- 占可见工作区 90% × 90%，居中（考虑菜单栏 + Dock）
- 视觉层不响应点击，下方 click-eater 层捕获背景点击并收起
- 通过 `NSEvent.addGlobalMonitorForEvents` 实现点外部关闭
- 通过累计 `.scrollWheel` 水平 delta 实现触控板滑动翻页

### 菜单栏
菜单栏常驻图标（▦ SF Symbol）：
- 打开 aLaunchpad
- 重新扫描应用
- 退出 aLaunchpad

### 应用图标
程序化绘制的拉丝银渐变 + 3×3 深炭黑描边格子 + 中心冰白柔光 —— 与 macOS 系统设置同色系。10 个 macOS 标准尺寸全部由 `Scripts/MakeIcon.swift` 生成，仓库不含任何外部图片资源。

### 启动行为
- 全新启动（Dock / 访达 / Spotlight）自动打开启动器面板。
- 已经在运行：点击 Dock 图标重新打开面板（由 `applicationShouldHandleReopen` 处理）。
- 关闭面板（Esc / 点外部 / 启动应用）**不会**退出 app —— 它继续驻留菜单栏。

### 功耗表现
- 面板隐藏时 **0.0% CPU**（已验证）
- 无定时器、无轮询、无后台 FSEvents 监听（仅显示期间激活）、无网络
- 全局事件监听仅在面板可见时安装，隐藏即移除
- 常驻内存约 150 MB（典型 SwiftUI app + 图标缓存）

---

## 键盘与鼠标

### 键盘
| 按键 | 操作 |
|---|---|
| ⌥ + Space | 切换启动器面板（全局快捷键） |
| ← / → | 移动选择一列；跨页时自动翻页 |
| ↑ / ↓ | 移动选择一行 |
| ⌘ + ← / ⌘ + → | 上一页 / 下一页 |
| Enter | 启动当前选中的应用 |
| Esc | 隐藏启动器 |

### 鼠标 / 触控板
| 手势 | 操作 |
|---|---|
| 点击应用图标 | 启动应用并隐藏启动器 |
| 右键应用图标 | 上下文菜单 —— 添加/移除收藏 · 归档/取消归档 · 在访达中显示 |
| 悬停或键盘选中应用图标 | 右上角浮出归档/取消归档小按钮 |
| 两指滑动（触控板 / Magic Mouse） | 上一页 / 下一页 |
| 点击底部指示点 | 跳转到指定页 |
| 点击启动器空白区域 | 隐藏启动器 |
| 点击其他应用 / 桌面 / Dock | 隐藏启动器 |
| 搜索栏右侧 📦 图标 | 切换归档应用视图 |
| 搜索栏右侧 ↕ 图标 | 排序菜单 —— 名称（A→Z / Z→A）· 添加时间（最新 / 最早） |

---

## 从源码构建

### 前置依赖

- macOS 13+
- Xcode 命令行工具（`xcode-select --install`）

### 构建

```bash
git clone https://github.com/mu0072/aLaunchpad.git
cd aLaunchpad
./build.sh
```

产物：`build/aLaunchpad.app`，架构与主机一致。如果 `aLaunchpad/Resources/AppIcon.icns` 不存在，脚本会自动生成。

### 构建通用二进制（arm64 + x86_64）

```bash
UNIVERSAL=1 ./build.sh
```

GitHub Releases 中的官方构建就是这样产生的。

### 手动重新生成图标

```bash
./make_icon.sh
```

### 本地安装

```bash
cp -R build/aLaunchpad.app /Applications/
open /Applications/aLaunchpad.app
```

### 保留在 Dock

1. 打开 app（Dock 中会出现图标）
2. 右键 Dock 图标 → **选项 → 在 Dock 中保留**

macOS 不会对 "在 Dock 中保留" 给出视觉反馈 —— 退出 app 后看图标是否仍在 Dock 中即可验证。

---

## 项目结构

```
aLaunchpad/                              # 项目根目录
├── README.md                            # 英文说明
├── README.zh-CN.md                      # 本文件（中文）
├── LICENSE                              # MIT 协议
├── CONTRIBUTING.md                      # 贡献指南
├── build.sh                             # 一键构建 → build/aLaunchpad.app
├── make_icon.sh                         # 生成 AppIcon.icns
├── set_icon.sh                          # 给 .app 设置访达图标
├── Scripts/
│   └── MakeIcon.swift                   # 程序化图标绘制
├── .github/workflows/
│   └── release.yml                      # CI：推 `v*` tag 即发版
└── aLaunchpad/                          # Swift 源码
    ├── Info.plist                       # bundle 配置
    ├── OpenPadApp.swift                 # @main 入口
    ├── AppDelegate.swift                # @MainActor — 菜单栏 + 生命周期
    ├── Resources/
    │   └── AppIcon.icns                 # 由 make_icon.sh 生成（已 gitignore）
    ├── Models/
    │   ├── AppItem.swift                # 应用值类型 + dateAdded
    │   └── Pinyin.swift                 # CFStringTransform + SearchTokens
    ├── Services/
    │   ├── AppScanner.swift             # 异步文件系统扫描 + 去重
    │   ├── AppLauncher.swift            # NSWorkspace async/await 启动
    │   ├── AppFolderWatcher.swift       # FSEventStream → 自动重扫
    │   ├── HotkeyManager.swift          # Carbon ⌥Space 全局快捷键
    │   └── IconCache.swift              # @MainActor NSImage 缓存
    ├── ViewModels/
    │   └── LauncherViewModel.swift      # @MainActor MVVM 核心
    ├── Views/
    │   ├── ContentView.swift            # 根视图 + click-eater 层
    │   ├── AppGridView.swift            # 分页 8×4 栅格 + 动态行距
    │   ├── AppIconView.swift            # 图标 + 标签 + 选中环 + 右键菜单
    │   ├── SearchBar.swift              # 顶部居中搜索框
    │   ├── SortMenuButton.swift         # ↕ 排序菜单
    │   ├── ArchiveToggleButton.swift    # 📦 归档视图切换
    │   └── VisualEffectView.swift       # NSVisualEffectView 桥接
    └── Window/
        └── WindowManager.swift          # LauncherPanel + 事件监听
```

严格 MVVM 架构：
- **Models** —— 不可变值类型，无副作用，可独立测试
- **Services** —— 系统边界（文件系统、NSWorkspace、Carbon），可单独 mock
- **ViewModels** —— `@MainActor` `ObservableObject`，唯一的可变状态持有者
- **Views** —— 纯 SwiftUI 渲染，所有事件通过闭包向上路由

---

## 架构决策

### 为什么用自定义 `NSPanel` 而不是 SwiftUI 的 `Window`？

SwiftUI 的 `Window` 和 `WindowGroup` 场景在 macOS 13 上暴露的面板配置不够。我们需要：
- 不激活（点击不会从其他应用的编辑器中夺走焦点）
- 能成为 key 窗口（这样搜索框才能接收输入）
- 浮于全屏应用之上
- 无边框 + 自定义圆角裁剪

`NSPanel` 子类（`LauncherPanel`）配合 `NSHostingView<ContentView>` 是唯一可靠的方案。

### 为什么用全局事件监听而非 `windowDidResignKey`？

`NSEvent.addGlobalMonitorForEvents` 只对**接收 app 进程之外**的事件触发。这正是点外部关闭想要的语义 —— 不会被 app 内菜单、弹出层、右键菜单误触发。`windowDidResignKey` 会在任何焦点切换（包括短暂的菜单）时过度触发。

### 为什么 `ContentView` 有三个独立的点击层？

```
┌─ VisualEffectView (allowsHitTesting=false)  — 仅视觉，永不吞点击
├─ Color (opacity 0.0001 + onTapGesture)       — click-eater，点击关闭
└─ VStack { 搜索栏, AppGridView, ... }          — 真实控件，赢得自己的手势
```

SwiftUI 手势优先级让子手势（图标 `.onTapGesture`、搜索框、排序菜单、指示点）优先于父级 click-eater，所以落在真实控件上的点击归控件处理，只有空白区域的点击才会落到 dismiss 回调。

### 为什么用分页而不是垂直滚动？

早期版本曾把栅格包在 `ScrollView` 里。一旦改为经典 Launchpad 的固定分页布局，滚动就显得多余 —— 每行都是真实可见的，用户可以用方向键、⌘←/→、双指滑动或指示点翻页。去掉滚动视图也去掉了面板内一层吞点击的视图。

### 为什么动态计算行距？

`LazyVGrid` 只接受静态 `spacing:` 参数，固定值会在栅格比可用高度短时在最后一行下方留下明显空隙。现在栅格通过 `GeometryReader` 读 `geo.size.height`，知道渲染单元高度（图标 88 + 标签 30 + padding = 138pt），计算 `spacing = (height − rows × cellHeight) / (rows − 1)`，钳制在 `[8, 48]`。单元使用固定高度标签框，保证每行真正等高，公式才能算准。

### 为什么用 Carbon 注册全局快捷键？

`NSEvent.addGlobalMonitorForEvents` 仅在 app **不是** key 时触发 —— 对于 "随时按 ⌥Space 就唤起，即使焦点在 Safari" 这个需求毫无用处。Carbon 的 `RegisterEventHotKey` 是 macOS 上唯一不要求辅助功能权限的真正全局快捷键 API。

### 为什么程序化生成图标？

让仓库无任何二进制资源。任何 clone 项目的人都能自包含构建；`./build.sh` 按需调用 `./make_icon.sh`。颜色和形状只是 `Scripts/MakeIcon.swift` 里约 30 行 Swift —— 改值、重构、搞定。

---

## 常见问题

**Q: 跟 Spotlight / Alfred / Raycast 有什么区别？**
A: aLaunchpad 只做一件事 —— *启动已安装的应用* —— 以经典 Launchpad 分页栅格呈现。不搜文件、不算算式、不搜网、不支持插件。如果你只用 Spotlight 启动应用，这个能用更快的键盘流程 + 拼音支持替代它，且待机零 CPU。

**Q: 支持拼音搜索吗？**
A: 支持。输入 `wx` 找 微信，`chrome` 找 Chrome。Token 在扫描阶段通过 `CFStringTransform` 预计算，无论应用多少个，搜索都是瞬时的。

**Q: 能在 Intel Mac 上运行吗？**
A: 能。Release 构建是通用二进制（arm64 + x86_64）。本地 `./build.sh` 默认只构建主机架构，用 `UNIVERSAL=1 ./build.sh` 即可生成通用版本。

**Q: 为什么隐藏时是 0% CPU？**
A: 无定时器、无轮询、无后台扫描。FSEvents 监听和全局事件监听仅在面板可见时安装，隐藏即移除。待机开销基本上只有菜单栏图标本身。

**Q: 会要 "辅助功能" 或 "完全磁盘访问" 权限吗？**
A: 不会。Carbon 全局快捷键 API 不需要辅助功能，应用扫描用公开的 `Bundle` / 文件系统 API 访问标准 `/Applications` 路径。

**Q: 如何消除 "无法验证开发者" 警告？**
A: 见 [首次打开（macOS Gatekeeper 提示）](#首次打开macos-gatekeeper-提示)。简言之：系统设置 → 隐私与安全性 → *仍要打开*。

**Q: 能改全局快捷键吗？还是固定 ⌥Space？**
A: 目前固定 —— 见 [路线图](#路线图)。欢迎 PR。

---

## 已知限制

| 限制 | 变通方式 |
|---|---|
| 未经 Apple 公证 | 首次打开在系统设置中允许（见 [Gatekeeper](#首次打开macos-gatekeeper-提示)） |
| 无快捷键冲突 UI | 如果 ⌥Space 被其他应用占用，注册会静默失败；菜单栏仍可用 |
| 分页大小固定 8×4 | 暂无偏好面板可改每页列/行数 |
| 无使用频率排序 | 所有应用权重相同，没有 MRU 排序 |
| 单屏 | 用 `NSScreen.main`，多显示器布局始终显示在主屏 |

---

## 路线图

1. **自定义快捷键 UI** —— 偏好面板，从 ⌥Space 重新绑定
2. **多显示器** —— 在光标所在屏幕显示
3. **图标 LRU + 磁盘缓存** —— 限制有几百个应用机器上的内存
4. **基于使用频率排序** —— 常用应用排前面
5. **可配置分页栅格** —— 允许偏好设置改列/行数
6. **拖拽排序 + 跨页拖拽** —— 更贴近原版 Launchpad 排序模型
7. **Developer ID 签名 + 公证** —— 去掉 Gatekeeper 提示
8. **测试** —— 给 `AppScanner`、`SearchTokens.matches`、`LauncherViewModel` 写单元测试
9. **国际化** —— 把硬编码的中文 UI 字符串提取到 `Localizable.strings`

---

## 卸载

```bash
pkill -x aLaunchpad
rm -rf /Applications/aLaunchpad.app

# 删除偏好（收藏、归档、排序等）
defaults delete local.alaunchpad.app 2>/dev/null

# 从 Launch Services 数据库移除
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -u /Applications/aLaunchpad.app 2>/dev/null
```

---

## 参与贡献

欢迎 PR 和 Issue。详见 [CONTRIBUTING.md](CONTRIBUTING.md)（开发环境、代码风格、PR 规范）。

仅使用 macOS 原生框架构建：
- SwiftUI（UI）
- AppKit（`NSPanel`、`NSVisualEffectView`、`NSWorkspace`、`NSStatusItem`、`NSHostingView`）
- Foundation（`Bundle`、`URLResourceKey`、`UserDefaults`）
- Carbon HIToolbox（`RegisterEventHotKey`）
- Core Foundation（`CFStringTransform`，用于拼音）

无任何第三方依赖。

---

## 开源协议

基于 [MIT License](LICENSE) 发布。
