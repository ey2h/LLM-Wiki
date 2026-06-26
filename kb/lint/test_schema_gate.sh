#!/usr/bin/env bash
# kb/lint/test_schema_gate.sh — 自测 schema_gate.py
#
# 流程:
# 1. 复制一个临时 mock concept 页到 kb/sources/2012/_test_mock.md(故意有缺字段)
# 2. 跑 schema_gate,期望红灯(exit 1)
# 3. 删除 mock,跑 schema_gate,期望绿灯(exit 0)
# 4. 输出 PASS/FAIL

set -uo pipefail
cd "$(dirname "$0")/../.."

GATE="kb/lint/schema_gate.py"
MOCK="kb/sources/2012/_test_schema_gate_mock.md"

cleanup() {
    [ -f "$MOCK" ] && rm "$MOCK"
}
trap cleanup EXIT

echo "=== Test 1: mock 缺字段应红灯 ==="

mkdir -p "$(dirname "$MOCK")"

cat > "$MOCK" << 'EOF'
---
type: Source
title: 测试 mock(故意缺 description)
created: 2026-06-26
updated: 2026-06-26
---
EOF

if python3 "$GATE"; then
    echo "❌ FAIL — 期望红灯(exit 1),实际绿灯"
    exit 1
fi
echo "✅ Test 1 PASS — 缺字段正确触发红灯"
echo

echo "=== Test 2: 修复后应绿灯 ==="

cat > "$MOCK" << 'EOF'
---
type: Source
title: 测试 mock(全合规)
description: 这是个测试用 mock,故意写全字段以触发绿灯
tags: [test, mock, schema-gate]
created: 2026-06-26
updated: 2026-06-26
year: 2012
doc_type: pdf
---
EOF

if ! python3 "$GATE"; then
    echo "❌ FAIL — 期望绿灯(exit 0),实际红灯"
    exit 1
fi
echo "✅ Test 2 PASS — 完整字段触发绿灯"
echo

echo "=== Test 3: 删除 mock 后应绿灯 ==="

rm "$MOCK"

if ! python3 "$GATE"; then
    echo "❌ FAIL — 删除 mock 后仍红灯"
    exit 1
fi
echo "✅ Test 3 PASS — 删除 mock 恢复绿灯"
echo

echo "=== ALL TESTS PASSED ==="
exit 0