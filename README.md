# wkt-platform deployment

三个独立后端容器的统一部署仓库。第一阶段由设备通过公网 IP 和端口直接访问服务：

| 服务 | 设备地址 | 镜像 |
| --- | --- | --- |
| AI | `http://139.129.17.67:18080` | `ghcr.io/anniconda-li/wkt-ai-server:0.1.0` |
| 对讲 | `ws://139.129.17.67:18081/intercom/ws` | `ghcr.io/anniconda-li/wkt-intercom-server:0.1.0` |
| OTA | `http://139.129.17.67:18082` | `ghcr.io/anniconda-li/wkt-ota-server:1.0.0` |

当前阶段不需要 Nginx、域名或 HTTPS，也不使用 OTA Token。OTA 明文 HTTP 仅用于实验室验证，不能防止中间人替换固件；进入正式公网生产阶段前应另行设计 TLS、固件签名和访问控制。

## 架构

```text
设备 / Internet
  |-- 0.0.0.0:18080 -> ai 容器       :8000
  |-- 0.0.0.0:18081 -> intercom 容器 :18081
  `-- 0.0.0.0:18082 -> ota 容器      :8000
```

三个服务没有 `depends_on`，可以独立拉取和重建。服务器只需克隆 `wkt-deploy`，不需要克隆 AI、对讲、OTA 三个业务源码仓库；Compose 会直接从 Public GHCR 拉取正式镜像。

## 首次部署

要求 Linux、Docker Engine、Docker Compose v2 和 Bash。云安全组及主机防火墙需由运维人员在仓库外人工配置，本仓库脚本不会修改它们。

```bash
cp .env.example .env
# 仅在未跟踪的 .env 中替换 AI 密钥占位符；不要提交 .env。
mkdir -p data/ai/uploads data/ai/outputs backups
# OTA 镜像使用 UID/GID 10001：
sudo install -d -o 10001 -g 10001 data/ota

./scripts/deploy.sh          # 只验证配置，不操作容器
./scripts/deploy.sh --apply  # 拉取正式镜像并启动三个服务
./scripts/status.sh
```

`.env.example` 已固定三个正式版本，禁止改用 `latest`。AI 的真实 API 密钥只写入服务器本地 `.env`；`.env` 已被 Git 忽略。

`compose.build.yaml` 仅供本地开发者在三个源码仓库相邻时构建调试，不是服务器部署依赖。

## 独立更新

```bash
./scripts/update-service.sh intercom
./scripts/update-service.sh ai
./scripts/update-service.sh ota
```

每次只执行目标服务的 `pull` 和 `up -d --no-deps`，不会重启另外两个服务。等价 OTA 命令为：

```bash
docker compose pull ota
docker compose up -d --no-deps ota
```

回滚时只需把目标服务的镜像变量改回旧的明确版本，再运行同一更新脚本。详细步骤见 [docs/operations.md](docs/operations.md)。

## 持久化与秘密

| 服务 | 宿主机目录 | 容器目录 | 内容 |
| --- | --- | --- | --- |
| AI | `${AI_DATA_ROOT}/uploads` | `/app/uploads` | 图片和上传的音频 |
| AI | `${AI_DATA_ROOT}/outputs` | `/app/outputs` | 生成的音频等输出 |
| OTA | `${OTA_DATA_ROOT}` | `/app/data` | SQLite、WAL、固件和临时发布文件 |
| 对讲 | 无 | 无 | 无持久化数据 |

固件、数据库、运行数据和秘密都不打入镜像，也不提交到 Git。OTA 数据备份使用 `./scripts/backup.sh`；脚本只在需要一致性快照时停止并恢复 OTA，不操作其他服务，不删除 Volume，也不执行 Docker prune。

## 健康检查

- AI：容器内 `GET http://127.0.0.1:8000/health`
- OTA：容器内 `GET http://127.0.0.1:8000/health`
- 对讲：容器内连接 `ws://127.0.0.1:18081/intercom/ws?device=wkt-deploy-healthcheck` 并完成 WebSocket 握手

本仓库只包含部署配置，不包含业务源码、证书、固件、数据库、生产数据或真实秘密。
