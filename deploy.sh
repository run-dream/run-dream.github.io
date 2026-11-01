#!/usr/bin/env bash
# run-dream 博客：本地构建 + 发布到阿里云（https://rundream.cn）
#
#   ./deploy.sh            发布全站
#   ./deploy.sh --subset   只发子集（category=Read 读书笔记 + 2025 年及以后）
#   ./deploy.sh --build    只构建到 ./dist，不发布
#
# 产物经 rsync 到主机 /srv/blog，nginx 在 rundream.cn 根路径直接出静态文件。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE="$ROOT/.build/site"
DROP="$ROOT/.build/dropped"
OVERRIDE="$ROOT/.build/aliyun.yml"
DIST="$ROOT/dist"
JEKYLL="${JEKYLL:-$HOME/.gem/ruby/2.6.0/bin/jekyll}"
HOST="${HOST:-openclaw}"
DEST="${DEST:-/srv/blog}"
SITE_URL="${SITE_URL:-https://rundream.cn}"

# 子集模式下，分类写着 Read、内容不是读书笔记的（RabbitMQ 的分类标错了）
DENY=("2020-11-12-RabbitMQ.md")

# 内网痕迹：命中就中止发布（发到备案过的境内域名上不能带这些）
INTERNAL_RE='netease\.com|\.corp\.|\.internal|[^0-9]10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}'

SUBSET=0
BUILD_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --subset) SUBSET=1 ;;
    --build)  BUILD_ONLY=1 ;;
    *) echo "未知参数: $arg" >&2; exit 2 ;;
  esac
done

post_date() {
  awk '/^date:/ { sub(/^date:[ \t]*/, ""); print substr($0, 1, 10); exit }' "$1"
}

post_category() {
  awk '/^category:/ { sub(/^category:[ \t]*/, ""); gsub(/[ \t\r]/, ""); print tolower($0); exit }' "$1"
}

keep() {
  local f="$1" d c
  d="$(post_date "$f")"
  c="$(post_category "$f")"
  [[ "$d" == 2025* || "$d" == 2026* ]] && return 0
  [[ "$c" == "read" ]]
}

scan_internal() {
  local hits
  hits="$(grep -rnoE "$INTERNAL_RE" "$STAGE/_posts" || true)"
  if [[ -n "$hits" ]]; then
    echo "发布中止：文章里有内网痕迹" >&2
    printf '%s\n' "$hits" | sed "s#$STAGE/##" >&2
    exit 1
  fi
}

build() {
  [[ -x "$JEKYLL" ]] || { echo "找不到 jekyll：$JEKYLL（见 aliyun 仓库 scripts/setup-blog-build.sh）" >&2; exit 1; }

  rm -rf "$STAGE" "$DROP" "$DIST"
  mkdir -p "$STAGE" "$DROP" "$DIST"
  rsync -a --exclude '.git' --exclude '_site' --exclude 'dist' --exclude '.build' \
        --exclude '.DS_Store' "$ROOT"/ "$STAGE"/

  local f b kept=0 dropped=0
  for f in "$STAGE"/_posts/*.md; do
    b="$(basename "$f")"
    if (( ! SUBSET )) || { keep "$f" && [[ ! " ${DENY[*]} " == *" $b "* ]]; }; then
      kept=$((kept + 1))
    else
      mv "$f" "$DROP/"
      dropped=$((dropped + 1))
    fi
  done

  # 文章里指向 GitHub Pages 的绝对图片地址改成站内根路径
  while IFS= read -r f; do
    sed -i '' -E 's#https?://run-dream\.github\.io/#/#g' "$f"
  done < <(grep -rl 'run-dream\.github\.io/' "$STAGE/_posts" || true)

  scan_internal

  cat > "$OVERRIDE" <<EOF
url: "$SITE_URL"
baseurl: ""
exclude: ["less", "node_modules", "Gruntfile.js", "package.json", "README.md", "specs", "vendor", "deploy.sh", "setup-gems.sh"]
collections:
  ai_tongjian:
    output: true
    permalink: /ai-story/:name/
EOF

  ( cd "$STAGE" && "$JEKYLL" build --config "_config.yml,$OVERRIDE" --destination "$DIST" >/dev/null )

  relocate_ai_story

  echo "构建完成：发布 ${kept} 篇，剔除 ${dropped} 篇 -> ${DIST}（${SITE_URL}）"
}

# AI通鉴 专栏：GitHub Pages 上仍是 /ai-tongjian/，境内站点挂到 /ai-story/
relocate_ai_story() {
  local landing=""
  if [[ -f "$DIST/ai-tongjian/index.html" ]]; then
    landing="$DIST/ai-tongjian/index.html"
  elif [[ -f "$DIST/ai-tongjian.html" ]]; then
    landing="$DIST/ai-tongjian.html"
  else
    return 0
  fi
  mkdir -p "$DIST/ai-story"
  mv "$landing" "$DIST/ai-story/index.html"
  rm -rf "$DIST/ai-tongjian" "$DIST/ai-tongjian.html"
  local f
  while IFS= read -r f; do
    sed -i '' -E 's#/ai-tongjian\.html#/ai-story/#g; s#/ai-tongjian/#/ai-story/#g' "$f"
  done < <(find "$DIST" -type f \( -name '*.html' -o -name '*.xml' \))
}

deploy() {
  [[ -f "$DIST/index.html" ]] || { echo "先跑 build" >&2; exit 1; }
  rsync -az --delete -e ssh "$DIST"/ "$HOST:$DEST"/
  echo "已同步到 $HOST:$DEST"
}

build
(( BUILD_ONLY )) || deploy
