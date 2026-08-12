# 服务部署契约

本文件记录 2026-07-16 对三个相邻业务仓库的只读核对结果；未修改相邻仓库。

| 服务 | 核对提交 | 正式镜像 | 容器端口 | 健康检查 | Volume |
| --- | --- | --- | ---: | --- | --- |
| intercom | `e5eb6ca` | `ghcr.io/anniconda-li/wkt-intercom-server:0.1.0` | `18081` | WebSocket `/intercom/ws?device=wkt-deploy-healthcheck` | 无 |
| ai | `b325752` | `ghcr.io/anniconda-li/wkt-ai-server:0.3.1` | `8000` | `GET /health` | `/app/uploads`、`/app/outputs` |
| ota | `214431f` | `ghcr.io/anniconda-li/wkt-ota-server:1.0.0` | `8000` | `GET /health` | `/app/data` |

## 对讲

Dockerfile 使用 Python 3.12、非 root 用户、`EXPOSE 18081` 和 `python main.py`。服务仅接受 `/intercom/ws`，并要求 `device` 查询参数。运行变量为 `INTERCOM_HOST`、`INTERCOM_WS_PORT` 及日志、队列、超时和实时窗口调优项；无持久化 Volume。

## AI

正式版本为 0.3.1，发布提交为 `b325752`。本版本在 0.3.0 基础上约束自我介绍只使用“我是博物馆AI讲解员。”，并限制文物介绍只出现省级及以上地名。Dockerfile 使用 Python 3.11，并以 `python -m uvicorn main:app --host 0.0.0.0 --port 8000` 启动单 worker；镜像自带 `GET /health` 检查。宿主机仍只映射 `18080 -> 8000`。

AI 运行环境包括 OpenAI-compatible 文本模型、DashScope、视觉、ASR、TTS 和设备协议配置。真实 API Key 只能存在于未跟踪的 `.env`；`.env.example` 仅使用 `REPLACE_WITH_SECRET` 占位符。

模型默认值与 0.2.0 实现一致：视觉使用 `qwen3.6-flash-2026-04-16`、关闭 thinking、超时 120 秒；ASR 主模型使用 `qwen3-asr-flash-2026-02-10`，并保留 `paraformer-realtime-v2` 回退；TTS 使用 `qwen3-tts-flash-2025-11-27`。

相机 JPEG/AOP1、相机幂等 SQLite、JPEG 分片、WAI1 SQLite/临时上传和 ROP1 回复均位于 `/app/uploads` 持久化挂载；普通生成输出继续写入 `/app/outputs`。SQLite、上传数据和回复不写入镜像或容器临时层，也不新增其他 Volume。

AI 新增独立 WAI1 地址：`ws://139.129.17.67:18080/ai/ws?device=walkie-01&protocol=wai1`。TCP 端口映射可直接承载 WebSocket，无需增加端口或反向代理。旧接口继续保留：

- `/ai/start`、`/ai/upload`、`/ai/finish`、`/ai/result_info`、`/ai/result_chunk`、`/ai/cancel`、`/ai/stop_audio`
- `/camera/upload`、`/camera/upload/chunk`、`/camera/upload/finish`、`/camera/upload/cancel`

部署必须保持单 Uvicorn worker、单副本，不能添加 `--workers`。WAI1 SQLite 可持久化上传元数据并协调 finish claim，但活跃连接替换、主动状态推送和后台 AI runtime task 仍是进程内状态。WebSocket 断开不会取消已开始的后台任务；进程重启不会自动恢复已经发出的外部模型调用。因此不能因为存在 SQLite 就扩成多 worker 或多副本。

## OTA

Dockerfile 使用 Python 3.12、UID/GID `10001`、`EXPOSE 8000`、`python -m app` 和 `GET /health`。`/app/data` 同时保存 SQLite/WAL、固件和发布临时文件，应整体持久化与备份。

当前程序读取的环境变量只有 `OTA_PUBLIC_BASE_URL`、`OTA_DATA_DIR` 和 `OTA_LOG_LEVEL`。第一阶段公共地址固定为 `http://139.129.17.67:18082`，仅支持绝对 HTTP URL；设备 API 不要求 Token。
