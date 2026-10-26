# GitHub 私有仓库初始化脚本

[`create-private-github-repo.sh`](create-private-github-repo.sh) 用于把一个本地项目初始化为 Git 仓库、提交当前文件、创建 GitHub 私有仓库、推送当前分支，并核验远端可见性及提交一致性。

## 前置条件

需要安装：

- `git`；
- [GitHub CLI](https://cli.github.com/) `gh`；
- `ripgrep`（`rg`），用于敏感信息启发式扫描。

首次使用前登录 GitHub：

```bash
gh auth login --hostname github.com --git-protocol https --web
```

脚本不会接收、保存或输出 GitHub Token。Git 凭据由 `gh auth setup-git` 配置和管理。

同时显式配置 Git 提交身份。可以全局配置：

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

也可以进入单个项目后去掉 `--global`，仅为该仓库设置。脚本不会接受 Git 根据主机名自动推导出的身份，以免意外提交本机名称或非预期邮箱。

## 最简用法

在任意目录执行脚本，并把项目目录作为最后一个参数：

```bash
/path/to/create-private-github-repo.sh ~/workspace/my-project
```

默认行为：

1. 仓库名取项目目录名；
2. 所有者取当前 `gh` 登录账号；
3. Git 远端名为 `origin`；
4. 新 Git 仓库使用 `main` 分支；已有 Git 仓库保留当前分支；
5. 有未提交内容时执行 `git add -A` 并创建提交；
6. GitHub 仓库始终创建为私有；
7. 使用普通推送，永不强推；
8. 推送后核验 GitHub 可见性以及本地、远端提交 SHA。

执行实际变更前，脚本会展示目标、状态和待提交文件，并要求确认。

## 常用示例

指定名称、描述和提交说明：

```bash
scripts/create-private-github-repo.sh \
  --repo trading-notes \
  --description "证券交易学习笔记" \
  --commit-message "docs: initialize knowledge base" \
  ~/workspace/trading-notes
```

创建到有权限的组织：

```bash
scripts/create-private-github-repo.sh \
  --owner my-organization \
  ~/workspace/my-project
```

只检查计划，不进行任何修改：

```bash
scripts/create-private-github-repo.sh --dry-run ~/workspace/my-project
```

用于自动化环境并跳过最终确认：

```bash
scripts/create-private-github-repo.sh --yes ~/workspace/my-project
```

## 失败后的断点续跑

如果 GitHub 仓库已经创建，但推送因网络等原因失败，重新执行时显式添加：

```bash
scripts/create-private-github-repo.sh \
  --reuse-existing \
  ~/workspace/my-project
```

脚本只会复用同名的**私有**仓库，并检查本地同名远端没有指向其他地址。普通推送若遇到不相关的远端历史仍会失败，脚本不会使用 `--force`。

## 敏感信息扫描

脚本在发布前检查当前项目文件：

- 私钥头；
- 常见 GitHub、AWS、Google 和 Slack Token 特征；
- Bearer Token；
- `.env`、私钥、证书和凭据类文件名。

命中时只输出文件名，不输出匹配到的值，并默认停止。确认属于安全的示例或误报后，可以显式添加：

```bash
--allow-secret-findings
```

该检查只是防误提交的启发式护栏，不会穷举检查已有 Git 历史，不能代替 `.gitignore`、专用 Secret Scanner 和人工审核。尤其在使用 `--yes` 前，应先执行一次 `--dry-run` 并自行检查项目文件；准备发布已有历史的仓库时，还应单独扫描历史提交。

## 完整参数

```text
--repo NAME
--owner OWNER
--description TEXT
--remote NAME
--commit-message TEXT
--reuse-existing
--allow-secret-findings
--yes
--dry-run
--help
```

## 安全边界

- 不支持创建公开仓库；
- 不自动覆盖已有远端；
- 不自动复用同名 GitHub 仓库；
- 不执行强推；
- 不处理远端分支冲突或合并不相关历史；
- 不修改已有提交；
- 如果目标目录位于另一个 Git 仓库内部，会给出嵌套仓库警告。
