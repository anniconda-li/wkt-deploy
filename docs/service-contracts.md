# 服务部署契约

本文件记录 2026-07-13 对三个相邻业务仓库的只读核对结果；未修改相邻仓库。

| 服务 | 核对提交 | 正式镜像 | 容器端口 | 健康检查 | Volume |
| --- | --- | --- | ---: | --- | --- |
| intercom | `e5eb6ca` | `ghcr.io/anniconda-li/wkt-intercom-server:0.1.0` | `18081` | WebSocket `/intercom/ws?device=wkt-deploy-healthcheck` | 无 |
| ai | `6b241cd` | `ghcr.io/anniconda-li/wkt-ai-server:0.1.0` | `8000` | `GET /health` | `/app/uploads`、`/app/outputs` |
| ota | `214431f` | `ghcr.io/anniconda-li/wkt-ota-server:1.0.0` | `8000` | `GET /health` | `/app/data` |

## 对讲

Dockerfile 使用 Python 3.12、非 root 用户、`EXPOSE 18081` 和 `python main.py`。服务仅接受 `/intercom/ws`，并要求 `device` 查询参数。运行变量为 `INTERCOM_HOST`、`INTERCOM_WS_PORT` 及日志、队列、超时和实时窗口调优项；无持久化 Volume。

## AI

Dockerfile 使用 Python 3.11、Uvicorn `0.0.0.0:8000`，镜像自带 `GET /health` 检查。相机图片与上传音频写入 `/app/uploads`，生成输出写入 `/app/outputs`。镜像内 `/app/data/artifacts` 是只读应用资源，不能用空运行目录覆盖。

AI 运行环境包括 OpenAI-compatible 文本模型、DashScope、视觉、ASR、TTS 和设备协议配置。真实 API Key 只能存在于未跟踪的 `.env`；`.env.example` 仅使用 `REPLACE_WITH_SECRET` 占位符。

## OTA

Dockerfile 使用 Python 3.12、UID/GID `10001`、`EXPOSE 8000`、`python -m app` 和 `GET /health`。`/app/data` 同时保存 SQLite/WAL、固件和发布临时文件，应整体持久化与备份。

当前程序读取的环境变量只有 `OTA_PUBLIC_BASE_URL`、`OTA_DATA_DIR` 和 `OTA_LOG_LEVEL`。第一阶段公共地址固定为 `http://139.129.17.67:18082`，仅支持绝对 HTTP URL；设备 API 不要求 Token。
