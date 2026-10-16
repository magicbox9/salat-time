#!/usr/bin/env python3
"""Build src/SalatTime/Assets/strings.json from the Mac app's text.

Sources: the translations.json heredoc in the Mac app's build.sh and the Swift
string tables in its main.swift. The Mac app lives on the repository's `main`
branch; point this at a checkout of it (default: the sibling "Salat Time Source"):

    python3 tools/extract_strings.py [path/to/mac/checkout]
"""
import json
import os
import re
import sys

HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MAC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else
                      os.environ.get("SALAT_MAC_SOURCE", os.path.join(HERE, "..", "Salat Time Source")))
if not os.path.isfile(os.path.join(MAC, "main.swift")):
    sys.exit(f"No Mac checkout at {MAC} (pass its path, or set SALAT_MAC_SOURCE)")
SWIFT = open(os.path.join(MAC, "main.swift"), encoding="utf-8").read()
BUILD = open(os.path.join(MAC, "build.sh"), encoding="utf-8").read()

TABLES = {
    "feature": "featureTranslations",
    "info": "prayerInfoTranslations",
    "picker": "mosquePickerTranslations",
    "view": "prayerViewTranslations",
    "living": "livingTranslations",
    "study": "quranStudyTranslations",
}
LANGS = ["en", "fr", "es", "ar", "zh", "hi", "bn", "ru", "pt", "ur"]
PAIR = re.compile(r'"((?:[^"\\]|\\.)+)"\s*:\s*"((?:[^"\\]|\\.)*)"')


def unescape(s):
    s = re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda m: chr(int(m.group(1), 16)), s)
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")


def table(name):
    start = SWIFT.index(f"private let {name}: [String: [String: String]] = [")
    depth, i = 0, SWIFT.index("[", SWIFT.index("=", start))
    j = i
    while True:
        c = SWIFT[j]
        if c == '"':
            j += 1
            while SWIFT[j] != '"':
                j += 2 if SWIFT[j] == "\\" else 1
        elif c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0:
                break
        j += 1
    body = SWIFT[i + 1:j]
    out, lang = {}, None
    for line in body.splitlines():
        m = re.match(r'\s{4}"([a-z]{2})"\s*:\s*\[\s*$', line)
        if m:
            lang = m.group(1)
            out.setdefault(lang, {})
            continue
        if lang:
            for k, v in PAIR.findall(line):
                out[lang][unescape(k)] = unescape(v)
    return out


def build_translations():
    m = re.search(r"cat > \"\$RESOURCES_DIR/translations.json\" <<'JSON_EOF'\n(.*?)\nJSON_EOF", BUILD, re.S)
    return json.loads(m.group(1))


result = {lang: {} for lang in LANGS}
base = build_translations()
for lang in LANGS:
    for k, v in base.get(lang, {}).items():
        result[lang][k] = v
for ns, name in TABLES.items():
    t = table(name)
    for lang in LANGS:
        for k, v in t.get(lang, {}).items():
            result[lang][f"{ns}:{k}"] = v

# Qur'an strings: a key list plus one row of values per language (read by featureText on the Mac).
def string_list(body):
    return [unescape(x) for x in re.findall(r'"((?:[^"\\]|\\.)*)"', body)]

start = SWIFT.index("private let quranTranslationKeys = [")
qkeys = string_list(SWIFT[start:SWIFT.index("]", start)].split("=", 1)[1])
start = SWIFT.index("private let quranTranslationRows: [String: [String]] = [")
end = SWIFT.index("\n]\n", start)
block = SWIFT[start:end]
for m in re.finditer(r'\n    "([a-z]{2})": \[(.*?)\n    \]', block, re.S):
    lang, values = m.group(1), string_list(m.group(2))
    for k, v in zip(qkeys, values):
        if lang in result:
            result[lang]["feature:" + k] = v

# Windows-only strings live in windows/tools/windows_strings.json and win over the rest.
extra_path = os.path.join(os.path.dirname(__file__), "windows_strings.json")
if os.path.exists(extra_path):
    extra = json.load(open(extra_path, encoding="utf-8"))
    for lang in LANGS:
        result[lang].update(extra.get(lang, {}))

out = os.path.join(HERE, "src", "SalatTime", "Assets", "strings.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
json.dump(result, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
print({lang: len(v) for lang, v in result.items()})
missing = sorted(set(result["en"]) - set(result["ar"]))
if missing:
    print("missing in ar:", len(missing), missing[:8], file=sys.stderr)
