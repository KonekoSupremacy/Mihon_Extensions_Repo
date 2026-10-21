#!/usr/bin/env bash
# local release, no CI needed
# usage: ./release.sh all.pawchive "short commit summary" [--no-push]
set -euo pipefail

ext="${1:?extension like all.pawchive}"
msg="${2:?commit summary}"
lang="${ext%%.*}"
name="${ext#*.}"

repo="$(cd "$(dirname "$0")" && pwd)"
src="$repo/Mihon_Manga_Extensions"
export JAVA_HOME="${JAVA_HOME:-/e/Tools/TachiyomiSetup/jdk-17}"

gradle="$src/src/$lang/$name/build.gradle.kts"
code=$(sed -n 's/.*versionCode *= *\([0-9]*\).*/\1/p' "$gradle" | head -1)
title=$(sed -n 's/^ *name *= *"\(.*\)".*/\1/p' "$gradle" | head -1)
version="1.6.$code"
apk="tachiyomi-$lang.$name-v$version.apk"

(cd "$src" && ./gradlew ":src:$lang:$name:assembleRelease" --offline -q)
cp "$src/src/$lang/$name/build/outputs/apk/release/$apk" "$repo/apk/$apk"

python - "$repo" "eu.kanade.tachiyomi.extension.$lang.$name" "$apk" "$version" "$((106000 + code))" <<'EOF'
import json, sys
repo, pkg, apk, version, code = sys.argv[1:]
for file, indent in (("index.json", 2), ("index.min.json", None)):
    path = f"{repo}/{file}"
    data = json.load(open(path, encoding="utf-8"))
    entry = next(e for e in data if e["pkg"] == pkg)
    entry.update(apk=apk, version=version, code=int(code))
    text = json.dumps(data, indent=indent, ensure_ascii=False) if indent else json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    open(path, "w", encoding="utf-8", newline="\n").write(text)
EOF

cd "$repo"
git add "apk/$apk" index.json index.min.json
git commit -q -m "$title v$version: $msg"
[ "${3:-}" = "--no-push" ] || git push origin HEAD
echo "released $apk"
