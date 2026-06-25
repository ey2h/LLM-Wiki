# Gemma 4 GGUF 部署指南(llama.cpp + A3000)

> 本文记录在本机 A3000 12G 上跑通 Gemma 4 GGUF 全流程,5 个关键踩坑。

## 环境

| 项 | 值 |
|---|---|
| GPU | NVIDIA RTX A3000 Laptop,12G 显存,compute_cap=8.6 |
| 系统 | Ubuntu 26.04,Linux 6.x |
| CUDA toolkit | nvidia-cuda-toolkit 12.4.131(`nvcc` 在 `/usr/lib/nvidia-cuda-toolkit/bin/nvcc`) |
| 头文件 | 散装在 `/usr/include/`(不是 `/usr/lib/nvidia-cuda-toolkit/include/`) |
| 驱动 | 595.71.05 |
| llama.cpp | **b9784**(`commit 09cedfd69`,self-compiled,CUDA enabled) |

## 模型清单

| 模型 | 文件 | 大小 | 显存(A3000)| 速度 |
|---|---|---|---|---|
| **E4B Q4_K_M** | `gemma-4-E4B-it-Q4_K_M.gguf` | 5.0G | **4.7G** | **55-57 tok/s** |
| E4B mmproj | `mmproj-gemma-4-E4B-it-Q8_0.gguf` | 534M | (随主模型上 GPU) | - |
| **12B Q4_K_M** | `gemma-4-12B-it-Q4_K_M.gguf` | 6.9G | **9.5G** | **25-26 tok/s** |
| 12B mmproj | `mmproj-gemma-4-12B-it-Q8_0.gguf` | 152M | (随主模型上 GPU) | - |

## 启动

**核心原则:一次只跑一个模型。** A3000 12G 装不下 12B + E4B 同时(16G > 12G)。日常保持空闲,按需启动。

```bash
# 启动 E4B(port 8001,快,适合 agent / 对话,5G 显存,55 tok/s)
serve-gemma e4b

# 启动 12B(port 8002,质量高,适合代码 / 推理,9.5G 显存,25 tok/s)
serve-gemma 12b

# 停
serve-gemma stop

# 状态/探活
serve-gemma status
serve-gemma health
```

### 显存预算(A3000 12G)

| 状态 | E4B (5G) | 12B (9.5G) | 显存余量 |
|---|---|---|---|
| **空闲(默认)** | ❌ 停 | ❌ 停 | 12G 满 |
| 跑 E4B | ✅ 64K ctx | ❌ | 7G |
| 跑 12B | ❌ | ✅ 8K ctx | 2.5G |
| 同时跑(❌ OOM) | ✅ | ✅ | -4G(不可行) |

### Hermes 集成

主模型是云端 API(MiniMax-M3 走 `https://api.minimax.io`),**不占本地显存**。本地模型只在 fallback 时被调。

**E4B 配为 Hermes 的 fallback provider**(自动容灾,主模型挂了接上):

```bash
# ~/.hermes/config.yaml 已配(查看):
grep -A8 custom_providers ~/.hermes/config.yaml
```

**手动使用 Gemma 4**:

```bash
# 1. 启动本地模型(必须在对话前启,fallback 不会自动起 server)
serve-gemma e4b
serve-gemma health    # 确认 port 8001: {"status":"ok"}

# 2. 显式指定 provider 走本地
hermes chat --provider gemma4-e4b --model gemma-4-E4B-it -q "你好"

# 3. 或依赖 fallback(主模型失败自动切)
hermes chat -q "你好"
```

**重要约束**:Hermes 强制要求 `context_length >= 64K`,所以 E4B 必须 `-c 65536` 启动,12B 用 UMA(`GGML_CUDA_ENABLE_UNIFIED_MEMORY=1`)才能跑 64K。

### 自动 fallback 的局限

Hermes fallback 是 LLM 路由层,管不了 llama-server 进程。如果主模型挂了而 E4B 没起,fallback 不会自动启 server —— 你需要手动 `serve-gemma e4b` 起好后重试。**日常保持 E4B 停,真需要时手动启 5 秒。**

## 关键踩坑(5 条)

### 1. GitHub release 没 Linux CUDA prebuilt ❌

我去查 GitHub release 页(https://github.com/ggml-org/llama.cpp/releases)发现:

| 平台 | Linux prebuilt |
|---|---|
| Windows | ✅ CUDA 12.4 / 13.3 |
| Linux | ❌ 只有 CPU / Vulkan / ROCm / OpenVINO / SYCL |

**Linux 上要 CUDA,只能源码编译**。

### 2. conda-forge 也没 Linux CUDA prebuilt ❌

`conda-forge/llama.cpp-feedstock`(`llama.cpp` 包名,带点号)确实提供 Linux 包,但全是 `cpu_mkl_h...` build,**没 CUDA 版**。

误以为有的原因:`docs/install.md` 表格写了 "CUDA (Windows and Linux)",实际只对 Python binding `llama-cpp-python` 有效(CUDA 11.2,太旧不能用)。

### 3. CUDA 头文件路径错位

第一次编译:
```
Could NOT find CUDAToolkit (missing: CUDAToolkit_INCLUDE_DIRECTORIES)
```

原因:`apt install nvidia-cuda-toolkit` 把 `cuda_runtime.h` 放在 `/usr/include/`,而不是 `/usr/lib/nvidia-cuda-toolkit/include/`(CMake 默认去找的位置)。

修法:unset `CUDA_HOME`,让 CMake 自己用 `/usr/include`。

### 4. modelscope CLI `--cache-dir` 不存在

文档/SDK 用 `--cache_dir`(下划线),CLI 用 `--local_dir`(下划线)。**`--cache-dir`(连字符)是错的**。

### 5. Gemma 4 thinking 模式会吞 content

第一次测试:
```json
{"content": "", "finish_reason": "length", "reasoning_content": "..."}
```

Gemma 4 把内部 thinking 放在 `reasoning_content`,OpenAI 风格 `content` 只装最终答案。200 tokens 全被 thinking 吃掉 → content 为空。

**修法**:max_tokens 至少给 800+ 让 thinking 写完。

## 性能对比(E4B vs 12B)

| 任务 | E4B(55 tok/s)| 12B(25 tok/s)|
|---|---|---|
| 简单问答 | ✅ OK | ✅ 更简洁 |
| 中文常识 | ✅ 5 人物 | ✅ 同 |
| 代码生成 | 没测 | ✅ **两种实现+注释,可直接跑** |
| 复杂推理 | 凑合 | **明显更强** |

**选型建议**:
- 工具调用、agent、对话 → **E4B**(快,省显存)
- 代码生成、文档写作、复杂推理 → **12B**(质量优先)

## OpenAI 兼容 API

```bash
curl http://127.0.0.1:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-4-E4B-it",
    "messages": [{"role":"user","content":"你好"}],
    "max_tokens": 800
  }'
```

`/health` 健康检查、`/v1/models` 列表、`/v1/chat/completions` 对话、`/v1/completions` 裸 completion。

## 升级路线

1. 当前 b9784 比最新 release b9754 还新 30 个 commit,**不急着升级**
2. 想升级:`cd ~/llama.cpp && git pull && cd build && cmake --build . -j 8 --config Release`
3. 大版本升级(Gemma 5/6):重编 + 下新 GGUF

## 关联项目

- `scripts/serve_gemma_llamacpp.sh` — 启停脚本
- `docs/mineru-gpu-install.md` — MinerU 部署(同 A3000)
- `docs/models-a3000.md` — 后续会汇总所有模型