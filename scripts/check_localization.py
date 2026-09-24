#!/usr/bin/env python3
"""本地化审计：扫描代码中引用的本地化 key，与各 target 的语言包比对。

用法：
    python3 scripts/check_localization.py            # 全部 target
    python3 scripts/check_localization.py iOS macOS  # 只查指定 target

检查项：
    1. 代码引用了 key，但四语言包中都不存在（会显示成原始 key 或走系统语言）
    2. 某个 key 只在部分语言包中存在（其余语言缺译文）
    3. 语言包里有、代码里没引用的 key（仅提示，不影响退出码）

退出码：0 = 无问题；1 = 存在缺失或语言间不一致。
"""

from __future__ import annotations

import glob
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# target 名 -> (代码根目录列表, 语言包根目录, 需要跳过的文件)
TARGETS: dict[str, tuple[list[str], str, set[str]]] = {
    "iOS": (["iFinance"], "iFinance/Resources/Localization", {
        "iFinance/Helper/LocalizationHelper.swift",  # L10n 自身实现
    }),
    "SwiftData": (["iFinanceSwiftData"], "iFinance/Resources/Localization", {
        "iFinanceSwiftData/Helper/LocalizationHelper.swift",
    }),
    "macOS": (["MaciFinance"], "MaciFinance/Resources/Localization", {
        "MaciFinance/Helpers/L10n.swift",
    }),
    "watchOS": (["WatchiFinance Watch App"], "WatchiFinance Watch App/Resources", {
        "WatchiFinance Watch App/L10n.swift",
    }),
}

LANGUAGES = ["zh-Hans", "zh-Hant", "en", "ja"]

# 代码中的 key 引用形式
KEY_PATTERNS = [
    r'L10n\.string\(\s*"([^"]+)"',
    r'String\(localized:\s*"([^"]+)"',
    r'NSLocalizedString\(\s*"([^"]+)"',
    r'LocalizedStringKey\(\s*"([^"]+)"',
    r'Text\(\s*"([^"]+\.[^"]+)"',
    r'(?:titleKey|subtitleKey|bodyKey)\s*:\s*"([^"]+\.[^"]+)"',
    r'(?:title|subtitle|message)\s*:\s*"([^"]+\.[^"]+)"',
    # SwiftUI 中接受 LocalizedStringKey 的常用 API
    r'(?:Label|Section|Button|TextField|Toggle|Picker|Link|Stepper)\(\s*"([^"]+\.[^"]+)"',
    r'\.(?:navigationTitle|alert|confirmationDialog|tabItem)\(\s*"([^"]+\.[^"]+)"',
]

# 合法的 key 形态：小写字母/数字/下划线分段，点号分隔（如 home.period.this_month）
KEY_SHAPE = re.compile(r"^[a-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+$")

# 形似 key、但实际是普通界面文本的字符串（例如数据库文件名）
IGNORE_KEYS = {"iFinance.sqlite"}


def code_keys(roots: list[str], skip: set[str]) -> dict[str, list[str]]:
    """返回 {key: [引用位置, ...]}"""
    found: dict[str, list[str]] = {}
    files: list[str] = []
    for root in roots:
        files += glob.glob(os.path.join(REPO_ROOT, root, "**", "*.swift"), recursive=True)

    for path in sorted(files):
        rel = os.path.relpath(path, REPO_ROOT)
        if rel in skip:
            continue
        text = open(path, encoding="utf-8").read()
        for pattern in KEY_PATTERNS:
            for match in re.finditer(pattern, text):
                key = match.group(1)
                if "\\(" in key:  # 动态拼接的 key 跳过
                    continue
                if not KEY_SHAPE.match(key):  # 过滤 "iFinance.sqlite" 这类普通文本
                    continue
                if key in IGNORE_KEYS:
                    continue
                line = text.count("\n", 0, match.start()) + 1
                found.setdefault(key, []).append(f"{rel}:{line}")
    return found


def string_keys(path: str) -> set[str]:
    keys: set[str] = set()
    for line in open(path, encoding="utf-8"):
        match = re.match(r'\s*"([^"]+)"\s*=', line)
        if match:
            keys.add(match.group(1))
    return keys


def check_target(name: str) -> bool:
    roots, loc_root, skip = TARGETS[name]
    packs = {
        lang: string_keys(os.path.join(REPO_ROOT, loc_root, f"{lang}.lproj", "Localizable.strings"))
        for lang in LANGUAGES
    }
    union = set().union(*packs.values())
    keys = code_keys(roots, skip)

    missing = sorted(k for k in keys if k not in union)
    partial = {k: [lang for lang, s in packs.items() if k not in s] for k in keys if k in union}
    partial = {k: v for k, v in partial.items() if v}
    unused = sorted(union - set(keys))

    ok = not missing and not partial
    print(f"== {name}: 代码引用 {len(keys)} 个 key，语言包 {len(union)} 个 key → {'✅ 通过' if ok else '❌ 有问题'}")
    if missing:
        print(f"   代码引用但四语言都缺失（{len(missing)}）:")
        for key in missing[:20]:
            print(f"     - {key}   ← {', '.join(keys[key][:2])}")
    if partial:
        print(f"   部分语言缺译文（{len(partial)}）:")
        for key, langs in list(partial.items())[:20]:
            print(f"     - {key}  缺 {', '.join(langs)}")
    if unused:
        print(f"   提示：语言包中未被代码引用（{len(unused)} 个，仅提示）: {', '.join(unused[:10])}"
              + (" …" if len(unused) > 10 else ""))
    return ok


def main() -> int:
    requested = sys.argv[1:] or list(TARGETS)
    unknown = [name for name in requested if name not in TARGETS]
    if unknown:
        print(f"未知 target: {', '.join(unknown)}；可选: {', '.join(TARGETS)}")
        return 1

    results = [check_target(name) for name in requested]
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
