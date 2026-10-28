# Spec Delta

## Purpose

规范用户在 Sileo 中添加或导入软件源时的条目校验行为，确保非法条目被拒绝，同时保留自定义 suite 与 components 的源配置能力。

## ADDED Requirements

### Requirement: 源条目的 URL 合法性校验

系统在添加或导入软件源时，必须校验每个条目是否为可解析的 `http`/`https` URL 且包含主机名；不满足条件的条目不得被添加，也不得阻止同一批次中其他合法条目继续处理。

#### Scenario: 合法 URL 添加成功
- **WHEN** 用户输入或粘贴 `https://repo.example.com/`
- **THEN** 系统将其识别为合法条目并正常添加该软件源

#### Scenario: 非法条目被拒绝
- **WHEN** 用户输入 `ftp://repo.example.com/`、缺少主机名的 URL，或无法解析为 URL 的文本
- **THEN** 系统跳过该条目，不创建软件源，其他合法条目不受影响

### Requirement: 自定义 suite 与 components 支持

系统必须继续接受带自定义 suite 或 components 的合法源条目，并按其配置添加为 dist 源；校验不得因 suite 不是 `./` 或 components 非空而丢弃条目。

#### Scenario: 带 suite 与 components 的源
- **WHEN** 用户输入 `https://repo.example.com/ stable main`
- **THEN** 系统按 suite `stable`、components `main` 添加 dist 源

#### Scenario: 导入列表中的多条目源
- **WHEN** 用户从 sources 列表导入包含默认源与带 suite/components 源的文本
- **THEN** 系统逐条校验，合法条目全部导入，非法条目被跳过并给出既有失败反馈
