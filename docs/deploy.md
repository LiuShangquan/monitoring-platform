# 部署说明

## 本地或单台 ECS

```bash
cd monitoring-platform
cp .env.example .env
docker compose config -q
docker compose up -d
docker compose ps
```

访问地址：

- Prometheus: `http://服务器IP:9090`
- Grafana: `http://服务器IP:3000`
- Alertmanager: `http://服务器IP:9093`
- Demo HTTP: `http://服务器IP:8080`

## Ansible 多服务器部署

编辑 `ansible/inventory.ini`：

```ini
[monitoring_servers]
YOUR_SERVER_IP ansible_user=root
```

编辑 `ansible/group_vars/all.yml`，至少修改 `grafana_admin_password`。

执行：

```bash
cd monitoring-platform
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

如果 CentOS 或 Alibaba Cloud Linux 镜像没有 Docker Compose 插件包，请先启用 Docker 官方仓库，或参考云厂商文档安装 Docker CE。

