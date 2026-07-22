# Sileo-roothide

基于 [Sileo/Sileo](https://github.com/Sileo/Sileo) 的 fork，面向 **RootHide** 环境，并叠加若干本地增强。

通用 Sileo 能力、本地化与捐赠等请以上游仓库为准。本 README **只说明本 fork 与上游的差异**。

当前包版本：`2.5.1-12`

---

## 差异一览

| 类别 | 本 fork 的改动 |
|------|----------------|
| 越狱 / 架构 | RootHide（`iphoneos-arm64e`）主架构；兼容 rootless 外架构；palera1n-roothide / Dopamine-roothide 检测 |
| 包选择 | 同一软件同时存在 roothide / rootless 包时，可正确拿到更新的 rootless 候选 |
| 软件源 | 禁用源、超时/HTTP 自动禁用、已禁用列表、导出源、HTTP 522 策略 |
| 更新 | App 层「屏蔽更新」（永久 / 版本上限），与 dpkg Hold 独立 |
| 构建 | 一键产出 rootful / rootless / roothide 三套 `.deb` |

---

## RootHide 与架构

- 运行时识别 RootHide bootstrap（`jbroot` / `.procursus_strapped`），命令路径与 dpkg 架构按环境切换。
- dpkg 架构：
  - RootHide：主架构 `iphoneos-arm64e`，并接受 rootless（`iphoneos-arm64`）作为 foreign
  - 纯 rootless：主架构 `iphoneos-arm64`
- 修复：仓库中同时存在 roothide 与更新的 rootless 包时，不再被旧的 roothide 包挡住，可访问到较新的 rootless 版本。
- 额外检测：`Palera1n-roothide`、`Dopamine-roothide` 等 RootHide 系越狱标识。

---

## 软件源管理增强

在上游刷新逻辑之上增加可配置的源状态管理（设置 → 相关入口）：

- **手动禁用 / 启用** 软件源（禁用后不参与刷新与包列表）
- **超时自动禁用**、**HTTP 错误自动禁用**（按状态码分组展示）
- **已禁用源** 独立管理页：手动禁用、超时自动禁用、HTTP 自动禁用分区；支持恢复与批量相关操作
- **导出软件源**（全部 / 仅启用中）
- **HTTP 522** 可按「站点错误」或「超时」策略分类，影响是否计入自动禁用

目标：慢源、挂源不再拖垮整次刷新，也方便事后恢复。

---

## 屏蔽更新（Block Updates）

App 层规则，**不写 dpkg hold**，与系统「Ignore Updates」并存：

| 模式 | 行为 |
|------|------|
| 永久屏蔽 | 该包不再出现在更新列表 / 角标 / 全部更新 |
| 版本上限 | 候选版本 ≤ 指定版本时隐藏；出现 **严格更高** 版本后重新提示 |

入口：

- 更新列表 / 已安装列表：长按 Context Menu
- 包详情：更多菜单
- 设置 → 已屏蔽更新管理

版本比较走 dpkg 规则。手动安装不拦截，只过滤「自动更新面」。

---

## 其他修复与体验

- Markdown 详情在网络失败时不再卡住 UI
- iPad：搜索状态与排队弹窗恢复相关一致性修复
- 软件源设置 / 已禁用列表 UI 整理（SF Symbols、分区展示等）

---

## 构建与打包

开发环境与上游类似：打开 `Sileo.xcodeproj`，配置 `DEVELOPMENT_TEAM`，可选：

```sh
git config core.hooksPath .githooks
```

产出全部 jailbreak 变体包：

```sh
./Scripts/build_packages.sh
```

产物在 `out/`：

| 文件名片段 | 架构 | 布局 |
|------------|------|------|
| `…_iphoneos-arm.deb` | rootful | `/Applications` |
| `…_iphoneos-arm64.deb` | rootless | `/var/jb/…` |
| `…_iphoneos-arm64e.deb` | roothide | 由 rootless 包转换（去掉 `var/jb` 前缀，架构改为 `iphoneos-arm64e`） |

也可单平台：

```sh
make clean package SILEO_PLATFORM=iphoneos-arm64   # rootless
make clean package SILEO_PLATFORM=iphoneos-arm     # rootful
```

roothide 包请用 `./Scripts/build_packages.sh`（或依赖脚本内的 rootless→roothide 转换）。

---

## 上游与贡献

- 上游项目：[Sileo/Sileo](https://github.com/Sileo/Sileo)
- 本仓库：面向 RootHide 与上述本地功能；PR / Issue 请优先描述 **本 fork 相关** 问题
- 通用 Sileo bug、完整本地化等，建议同时对照上游

本地化：本 fork 在屏蔽更新等新增字符串上维护了 **en + zh-Hans**；其余语言仍可参考上游 Crowdin。

---

## License

与上游一致，见 [LICENSE](./LICENSE)（Sileo Project）。
