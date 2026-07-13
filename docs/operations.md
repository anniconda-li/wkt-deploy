# 运维说明

## 第一阶段部署流程

1. 在服务器克隆本 `wkt-deploy` 仓库；无需克隆三个业务源码仓库。
2. 将 `.env.example` 复制为不受 Git 跟踪的 `.env`，填写 AI 所需的真实密钥。
3. 准备 `data/ai/uploads`、`data/ai/outputs`、`data/ota` 和 `backups` 目录。
4. 运行 `./scripts/deploy.sh`，只做首次配置验证。
5. 人工确认公网端口和实验室使用范围后，运行 `./scripts/deploy.sh --apply` 启动三个服务。
6. 运行 `./scripts/status.sh` 查看状态。

设备直接访问：

- AI：`http://139.129.17.67:18080`
- 对讲：`ws://139.129.17.67:18081/intercom/ws`
- OTA：`http://139.129.17.67:18082`

Compose 直接绑定 `0.0.0.0`。当前不需要 Nginx、域名或 HTTPS，也不使用 OTA Token。HTTP OTA 仅限实验室验证；脚本不会连接远程服务器或修改云安全组和防火墙。

## 独立更新与回滚

```bash
./scripts/update-service.sh intercom
./scripts/update-service.sh ai
./scripts/update-service.sh ota
```

每个命令只执行：

```bash
docker compose pull SERVICE
docker compose up -d --no-deps SERVICE
```

因此不会联动重启其他服务。回滚时将 `.env` 中目标服务镜像改回旧的明确版本，再运行对应更新命令；不要使用 `latest`，不要删除 Volume 或 prune Docker。

## 状态、日志和健康检查

```bash
./scripts/status.sh
docker compose logs --tail=200 -f intercom
docker compose logs --tail=200 -f ai
docker compose logs --tail=200 -f ota
curl --fail http://139.129.17.67:18080/health
curl --fail http://139.129.17.67:18082/health
```

AI 和 OTA 使用 HTTP `GET /health`。对讲使用 `/intercom/ws?device=wkt-deploy-healthcheck` 的真实 WebSocket 握手。

## OTA 备份与恢复

`./scripts/backup.sh` 归档完整 `OTA_DATA_ROOT`，包括 SQLite 数据库/WAL、固件和其他持久化文件。OTA 正在运行时，脚本只停止 OTA，创建 gzip tar 快照，再恢复 OTA；其他服务不受影响。

Linux 首次启动前应让 UID/GID `10001` 可写 OTA 目录：

```bash
sudo install -d -o 10001 -g 10001 ./data/ota
```

恢复流程：

1. `docker compose stop ota`；
2. 将当前 OTA 数据目录移到安全的临时位置；
3. 用 `tar -tzf BACKUP` 检查备份；
4. 将备份解压到 `OTA_DATA_ROOT` 的父目录；
5. 检查 UID/GID 和权限；
6. `docker compose start ota`，验证健康检查和实验室固件下载。

AI 的上传与输出目录使用宿主机文件备份工具处理。对讲无持久化 Volume。

## 数据与秘密边界

`.env`、固件、SQLite、上传文件、生成输出和备份都不得提交 Git，也不得打入镜像。Public GHCR 镜像只包含应用和只读资源；运行数据通过 Volume 持久化，AI 密钥仅通过服务器本地 `.env` 注入。
