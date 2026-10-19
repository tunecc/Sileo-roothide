# Spec Delta

## Purpose

规范 Sileo 与外部 Patcher App（Umbra Patcher / 旧版 RootHide Patcher）之间的检测优先级、deb 交接与安装引导行为，保证换装任一版本的 Patcher 后转换流程保持可用。

## ADDED Requirements

### Requirement: Patcher 候选优先级

Sileo 必须按固定有序列表检测 Patcher：依次为 `wiki.qaq.umbra.patcher`（Umbra Patcher）、`com.roothide.patcher`（旧版 RootHide Patcher）；列表中第一个满足条件的候选生效。

#### Scenario: 仅安装 Umbra Patcher
- **WHEN** 设备上只安装了 `wiki.qaq.umbra.patcher`
- **THEN** Sileo 将其识别为可用 Patcher，转换与交接均指向该 App

#### Scenario: 仅安装旧版 Patcher
- **WHEN** 设备上只安装了 `com.roothide.patcher`
- **THEN** Sileo 继续将其识别为可用 Patcher，行为与改动前一致

### Requirement: deb 交接

用户确认 Convert 后，Sileo 下载目标 deb 并交给候选列表中第一个可通过系统打开方式 API 分享的 Patcher App；分享失败或无可用 App 时回退系统分享面板。

#### Scenario: 可用 Patcher 存在
- **WHEN** 候选列表中存在已安装且分享成功的 Patcher
- **THEN** deb 文件直接交给该 Patcher，不弹出系统分享面板

#### Scenario: 无可用 Patcher App
- **WHEN** 候选列表中没有任何 App 可接受分享
- **THEN** 弹出系统分享面板，用户自行选择去向（现有回退行为）

### Requirement: 未安装时的安装引导

候选列表中没有任何已安装的 Patcher 时，警告弹窗的 "Get Patcher" 动作跳转 `sileo://package/wiki.qaq.umbra.patcher` 详情页；该详情页无法打开时回退 `sileo://package/com.roothide.patcher`。

#### Scenario: 两个 Patcher 均未安装
- **WHEN** 设备上未检测到任何候选 Patcher 包
- **THEN** "Get Patcher" 打开 Umbra Patcher 的包详情页；用户可从详情页安装

#### Scenario: 新包详情页不可达
- **WHEN** Umbra Patcher 不在当前源列表中、详情页无法构建
- **THEN** 回退打开旧版 `com.roothide.patcher` 详情页；仍不可达时不显示跳转按钮（保持现有约束）

### Requirement: 已装 Patcher 的直接转换

候选列表中存在已安装的 Patcher 包时，警告弹窗显示 "Convert" 按钮；点击后直接进入下载并交接流程，不再跳转详情页。

#### Scenario: 已安装任一 Patcher
- **WHEN** 候选列表中检测到已安装的 Patcher 包
- **THEN** 按钮显示 "Convert"，点击后下载 deb 并按交接要求交给对应 Patcher
