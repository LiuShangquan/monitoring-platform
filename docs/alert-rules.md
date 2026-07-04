# 告警规则说明

规则文件位于 `prometheus/rules/`：

- `host_alerts.yml`: 主机宕机、CPU、内存、磁盘、IO、负载、网络流量。
- `container_alerts.yml`: cAdvisor 不可用、容器重启、容器指标消失、容器 CPU/内存。
- `service_alerts.yml`: HTTP 服务不可用、HTTP 探测延迟过高。

核心 PromQL 示例：

```promql
100 - avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100 > 80
```

```promql
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 80
```

```promql
(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) * 100 > 85
```

```promql
probe_success{job="blackbox-http"} == 0
```

Alertmanager 使用 `group_by` 聚合告警，通过 `inhibit_rules` 抑制主机宕机时的低级别告警，并通过 `send_resolved: true` 发送恢复通知。

