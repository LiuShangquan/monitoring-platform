# 阿里云 CI/CD 持续集成与部署

本项目是 Docker Compose 编排项目，不需要构建业务镜像。推荐使用阿里云云效 Flow 做流水线，实现：

1. 代码提交后自动触发流水线。
2. 校验 YAML、JSON、Docker Compose 配置。
3. 打包项目文件。
4. 通过 SSH 发布到 ECS。
5. 在 ECS 上执行 `docker compose pull && docker compose up -d`。
6. 执行健康检查并保留可回滚版本。

## 推荐架构

```mermaid
flowchart LR
  Dev[开发者 Git Push] --> Repo[Codeup/GitHub/Gitee]
  Repo --> Flow[云效 Flow 流水线]
  Flow --> Check[配置校验]
  Check --> Package[打包项目]
  Package --> ECS[ECS SSH 部署]
  ECS --> Compose[Docker Compose Up]
  Compose --> Monitor[Prometheus/Grafana/Alertmanager]
```

## 前置准备

### 1. 代码仓库

可以选择：

- 阿里云 Codeup
- GitHub
- Gitee

如果想在阿里云内部闭环，推荐 Codeup + Flow。

### 2. ECS 准备

在 ECS 上提前安装：

```bash
docker version
docker compose version
```

准备部署目录：

```bash
sudo mkdir -p /opt/monitoring-platform
sudo chown -R root:root /opt/monitoring-platform
```

首次创建生产环境变量：

```bash
cd /opt/monitoring-platform
cp .env.example .env
vi .env
```

至少修改：

```bash
GF_SECURITY_ADMIN_PASSWORD=YOUR_PASSWORD
SERVER_IP=YOUR_SERVER_IP
```

国内 ECS 建议先配置 Docker 镜像加速：

```bash
ACR_MIRROR=https://YOUR_ACR_ACCELERATOR_ID.mirror.aliyuncs.com sudo -E scripts/configure_docker_mirror.sh
```

### 3. 云效 Flow 凭据

在云效 Flow 中配置：

- 代码源授权：Codeup/GitHub/Gitee。
- ECS SSH 主机：服务器公网 IP、SSH 用户、端口、私钥。
- 可选变量：
  - `DEPLOY_DIR=/opt/monitoring-platform`
  - `SERVER_IP=YOUR_SERVER_IP`
  - `ACR_MIRROR=https://YOUR_ACR_ACCELERATOR_ID.mirror.aliyuncs.com`

## 流水线阶段设计

### 阶段一：代码检查

Flow 中添加“命令行脚本”任务：

```bash
set -e

echo "[ci] Check Docker Compose config"
docker compose config -q

echo "[ci] Check YAML and JSON"
python3 - <<'PY'
import json
import pathlib
import yaml

root = pathlib.Path(".")
for path in list(root.rglob("*.yml")) + list(root.rglob("*.yaml")):
    yaml.safe_load(path.read_text(encoding="utf-8"))

for path in root.rglob("*.json"):
    json.loads(path.read_text(encoding="utf-8"))

print("yaml/json ok")
PY

echo "[ci] Check shell shebang"
find scripts -name "*.sh" -type f -exec awk 'NR==1 && $0!="#!/bin/bash"{print FILENAME ": missing #!/bin/bash"; exit 1}' {} \;
```

如果 Flow 的构建环境没有 Docker，可以把 `docker compose config -q` 放到 ECS 部署阶段执行。

### 阶段二：打包制品

Flow 中添加“命令行脚本”任务：

```bash
set -e

mkdir -p output
tar \
  --exclude='.git' \
  --exclude='.env' \
  --exclude='backups' \
  --exclude='.chaos' \
  -czf output/monitoring-platform.tar.gz .

ls -lh output/monitoring-platform.tar.gz
```

将 `output/monitoring-platform.tar.gz` 设置为流水线制品。

### 阶段三：部署到 ECS

Flow 中添加“主机部署/SSH 脚本”任务，上传制品到 ECS 后执行：

```bash
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/monitoring-platform}"
RELEASE_DIR="$DEPLOY_DIR/releases/$(date +%Y%m%d-%H%M%S)"
PACKAGE="${PACKAGE:-monitoring-platform.tar.gz}"

echo "[deploy] Create release directory: $RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "[deploy] Extract package"
tar -xzf "$PACKAGE" -C "$RELEASE_DIR"

echo "[deploy] Preserve production .env"
if [ -f "$DEPLOY_DIR/current/.env" ]; then
  cp "$DEPLOY_DIR/current/.env" "$RELEASE_DIR/.env"
elif [ -f "$DEPLOY_DIR/.env" ]; then
  cp "$DEPLOY_DIR/.env" "$RELEASE_DIR/.env"
else
  cp "$RELEASE_DIR/.env.example" "$RELEASE_DIR/.env"
  echo "Please edit $RELEASE_DIR/.env before production use." >&2
fi

echo "[deploy] Switch current symlink"
ln -sfn "$RELEASE_DIR" "$DEPLOY_DIR/current"
cd "$DEPLOY_DIR/current"

echo "[deploy] Ensure scripts executable"
chmod +x scripts/*.sh scripts/chaos/*.sh

echo "[deploy] Validate compose"
docker compose config -q

echo "[deploy] Pull images"
docker compose pull

echo "[deploy] Start stack"
docker compose up -d

echo "[deploy] Show status"
docker compose ps

echo "[deploy] Optional runtime check"
scripts/check.sh || true
```

如果你的 Flow SSH 插件上传后的包名不是 `monitoring-platform.tar.gz`，把 `PACKAGE` 改成实际文件名。

## 回滚

ECS 上保留了 `releases` 目录，可以手动回滚：

```bash
cd /opt/monitoring-platform
ls -lt releases
ln -sfn /opt/monitoring-platform/releases/需要回滚的版本 current
cd current
docker compose up -d
docker compose ps
```

## 与 ACR 结合

本项目默认使用 Prometheus、Grafana、Alertmanager 等官方镜像，因此 CI 不一定要构建镜像。ACR 的作用主要有两个：

- 配置 Docker Hub 镜像加速，解决 ECS 拉取 Docker Hub 失败。
- 如果默认的 `ghcr.io/google/cadvisor:0.55.1` 在 ECS 上仍不可达，可同步到自己的 ACR 仓库，再通过 `.env` 覆盖：

```bash
CADVISOR_IMAGE=registry.cn-hangzhou.aliyuncs.com/YOUR_NAMESPACE/cadvisor:0.55.1
```

如果以后你给项目增加自研 webhook 服务、告警适配器或运维 API，再使用 Flow 构建镜像并推送到 ACR。

## 最小可用流水线

最小版本只需要三个阶段：

1. 拉取代码。
2. 执行 `docker compose config -q`。
3. SSH 到 ECS 执行：

```bash
cd /opt/monitoring-platform/current
git pull
docker compose pull
docker compose up -d
docker compose ps
```

不过更推荐使用“打包制品 + releases 目录”的方式，方便回滚，也更像真实生产项目。

## GitHub Actions + SSH 部署到阿里云 ECS

仓库已提供 workflow 示例：`.github/workflows/deploy-to-ecs.yml`。当代码推送到 `main` 分支时，GitHub Actions 会先校验配置，再通过 SSH 上传压缩包到 ECS，并在 ECS 上执行 Docker Compose 部署。

### GitHub Secrets

在 GitHub 仓库页面进入：

`Settings -> Secrets and variables -> Actions -> New repository secret`

新增以下 Secrets：

| 名称 | 示例 | 说明 |
| --- | --- | --- |
| `ECS_HOST` | `YOUR_SERVER_IP` | ECS 公网 IP |
| `ECS_PORT` | `22` | SSH 端口 |
| `ECS_USER` | `root` | SSH 用户 |
| `ECS_SSH_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | 登录 ECS 的私钥内容 |
| `DEPLOY_DIR` | `/opt/monitoring-platform` | ECS 部署目录 |
| `GRAFANA_ADMIN_PASSWORD` | `YOUR_PASSWORD` | Grafana 管理员密码 |
| `SERVER_IP` | `YOUR_SERVER_IP` | 文档和脚本使用的服务器 IP |
| `CADVISOR_IMAGE` | `registry.cn-hangzhou.aliyuncs.com/YOUR_NAMESPACE/cadvisor:0.55.1` | 可选，ECS 无法访问 GHCR 时覆盖 cAdvisor 镜像 |
| `ECS_KNOWN_HOSTS` | `ssh-keyscan` 输出 | 可选，推荐填写以固定主机指纹 |

获取 `ECS_KNOWN_HOSTS`：

```bash
ssh-keyscan -p 22 YOUR_SERVER_IP
```

### ECS 首次准备

登录 ECS：

```bash
ssh root@YOUR_SERVER_IP
```

安装 Docker 和 Compose 插件后，创建部署目录：

```bash
mkdir -p /opt/monitoring-platform/releases
```

如果是国内 ECS，先配置镜像加速：

```bash
ACR_MIRROR=https://YOUR_ACR_ACCELERATOR_ID.mirror.aliyuncs.com sudo -E scripts/configure_docker_mirror.sh
```

首次部署后，实际运行目录是：

```bash
/opt/monitoring-platform/current
```

### GitHub 首次发布

把代码推送到 GitHub：

```bash
git add .
git commit -m "add monitoring platform ci cd"
git branch -M main
git remote add origin git@github.com:YOUR_NAME/monitoring-platform.git
git push -u origin main
```

进入 GitHub 仓库的 `Actions` 页面，点击 `Deploy to Alibaba Cloud ECS` 查看流水线日志。

### 回滚

在 ECS 上执行：

```bash
cd /opt/monitoring-platform
ls -lt releases
ln -sfn /opt/monitoring-platform/releases/目标版本 current
cd current
docker compose up -d
docker compose ps
```
