# 常见问题排查

## Docker 镜像拉取失败

如果执行 `docker compose pull` 出现：

```text
Get "https://registry-1.docker.io/v2/": connect: connection refused
```

说明 ECS 到 Docker Hub 不通或被限流，不是 Compose 配置错误。推荐处理：

```bash
cd monitoring-platform
ACR_MIRROR=https://YOUR_ACR_ACCELERATOR_ID.mirror.aliyuncs.com sudo -E scripts/configure_docker_mirror.sh
docker compose pull
docker compose up -d
```

`YOUR_ACR_ACCELERATOR_ID` 在阿里云容器镜像服务 ACR 的“镜像工具 -> 镜像加速器”页面获取。

如果只有 `cadvisor` 失败，原因通常是当前 ECS 无法访问 cAdvisor 镜像仓库。项目默认使用 `ghcr.io/google/cadvisor:0.55.1`，如果 GHCR 仍不可达，可以把该镜像同步到自己的阿里云 ACR 仓库，然后在 `.env` 中覆盖：

```bash
CADVISOR_IMAGE=registry.cn-hangzhou.aliyuncs.com/YOUR_NAMESPACE/cadvisor:0.55.1
```

再执行：

```bash
docker compose pull cadvisor
docker compose up -d cadvisor
```

## Prometheus Targets 不是 UP

1. 执行 `docker compose ps` 检查容器是否运行。
2. 执行 `docker compose logs prometheus` 查看采集配置错误。
3. 执行 `scripts/check.sh` 使用 promtool/amtool 检查配置。
4. 确认 ECS 安全组和本机防火墙放行所需端口。

## Grafana 无法登录

默认账号来自 `.env`：

```bash
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=YOUR_PASSWORD
```

如果已经初始化过 Grafana volume，修改 `.env` 不会重置旧密码，因为 Grafana 首次启动后会把管理员账号写入自己的数据库。

推荐重置方式：

```bash
scripts/reset_grafana_password.sh 'NEW_PASSWORD'
```

也可以先修改 `.env`：

```bash
GF_SECURITY_ADMIN_PASSWORD=NEW_PASSWORD
```

然后执行：

```bash
scripts/reset_grafana_password.sh
```

演示环境如果不需要保留 Grafana 数据，也可以删除 volume 后重新初始化：

```bash
CLEAN_VOLUMES=true scripts/clean.sh
docker compose up -d
```

## cAdvisor 启动失败

确认宿主机是 Linux 且 Docker 正常运行。cAdvisor 需要读取 `/sys`、`/var/lib/docker` 等宿主机路径，在 Docker Desktop 或非 Linux 环境中可能无法完整工作。

## Alertmanager 没收到告警

1. Prometheus 页面打开 `Status -> Rules` 确认规则加载成功。
2. Prometheus 页面打开 `Alerts` 查看告警是否进入 firing。
3. Alertmanager 页面查看告警是否被接收、分组或抑制。
4. 将 `alertmanager/alertmanager.yml` 中 webhook URL 替换为真实通知服务地址。
