# Holo3.1-4B 实测报告(2026-06-25)

## 测试环境
- 硬件:A3000 12G 显卡(只跑这一个模型,4.4G 显存)
- llama.cpp b9784 + CUDA
- 模型:`prithivMLmods/Holo-3.1-4B-GGUF` 的 Q4_K_M(2.9G) + mmproj-bf16(644M)
- Server port:8003,ctx=4096

## 性能数据
| 项 | 值 |
|---|---|
| 加载显存 | 4.4G / 12G |
| 文本生成速度 | **58-60 tok/s** |
| 首 token 延迟 | ~90ms |
| thinking 模式 | ✅(reasoning_content 字段,Qwen 3.5 风格)|

## 实测能力

### ✅ 强项
- **JSON 输出格式**(基本干净)
- **图测中文布局识别**(能数清楚输入框/按钮数量)
- **reasoning 字段可独立取**(对 agent 流程友好)

### ❌ 严重问题

**1. 无限循环生成(致命)**
```
prompt: "你是谁?用一句话回答。"
output: "你是谁?用一句话回答。你是谁?你是谁?你是谁?...(重复 700+ 次直到 max_tokens 截断)"
```
- **触发条件**:中文 + "一句话回答" 这种短 prompt
- **原因**:Q4_K_M 量化损失在循环 token 上解循环失败
- **解决**:换 Q5_K_M 或 Q8_0(代价:文件大一倍,显存 +1-2G)

**2. 中文字符乱码**
- 输出含 "知识克隆" / "身体" / "Форум"(俄文)等噪音
- 4B 模型本身中文训练不够,Q4 量化又砍一刀

**3. GUI grounding 坐标错乱**
- prompt: "点击红色'登录'按钮"
- 真实位置:y=300
- 模型输出:`{"action":"click","x":150,"y":490,"target":"的健康"}` — **y 错 190px,target 是乱码**

## 结论与建议

### 推荐使用
- ✅ **英文 desktop/web 截图**(Holo3.1 训练数据以英文为主)
- ✅ **任务级 JSON 决策**(虽然坐标不精确,结构稳定)
- ✅ **GUI 元素的"枚举 + 描述"**(识别出有几个按钮/输入框)
- ❌ **精确坐标点击**(必须换 9B 或上 vision-tuned 后续模型)
- ❌ **通用中文对话**(能力比 Gemma E4B 弱得多)

### 下一步选择
| 选项 | 描述 | 推荐度 |
|---|---|---|
| **A. 试 Q5_K_M / Q8_0** | 量化精度提升 → 循环 bug 可能消失,中文改善 | ⭐⭐⭐ 值得试 |
| **B. 试 Holo3.1-9B** | 模型大一倍,能力应该有质变,但 9G 显存满载 | ⭐⭐ 跟 E4B 撞 |
| **C. 当前 4B Q4_K_M 凑合用** | 只用于英文场景,中文禁用 | ⭐ 短期可接受 |
| **D. 跳过 Holo3.1** | 转回主线 Phase 2/3 | ⭐⭐⭐⭐⭐ |

**我的建议**:先试 **A(Q5_K_M)**,5 分钟看效果,再决定 B/C/D。

## 测试命令(可复用)

```bash
# 启 server
llama-server -m ~/models/holo3-gguf/4b/Holo-3.1-4B.Q4_K_M.gguf \
  --mmproj ~/models/holo3-gguf/4b/Holo-3.1-4B.mmproj-bf16.gguf \
  -ngl 999 -c 4096 --port 8003

# 健康
curl http://127.0.0.1:8003/health

# 测试脚本
python3 /tmp/holo3_test.py
```

## 关键 API 差异(Gemma 4 vs Holo3.1)

| 维度 | Gemma 4 | Holo3.1 |
|---|---|---|
| 思考模式字段 | 内嵌在 content | **独立 `reasoning_content`** |
| 关闭 thinking | 不支持 | `chat_template_kwargs: {enable_thinking: false}` |
| Function calling | 不支持 | 原生支持(`tools` 字段)|
| 默认速度 | 57 tok/s (E4B) | 58 tok/s (4B) |