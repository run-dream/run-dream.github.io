#!/usr/bin/env bash
# 本机装 jekyll 3.9.5（与 GitHub Pages 对齐），供 ./deploy.sh 构建站点。
#
# why 这么麻烦：macOS 自带 ruby 2.6 只能装纯 ruby 的 gem——原生扩展编译会失败
# （SDK 里的 Ruby.framework 缺 ruby/config.h，ffi/sassc 都过不去）。而 jekyll
# 的全部必需依赖里，只有 serve/watch 用到的 em-websocket、jekyll-watch、sass-listen
# 会拖进原生扩展。构建只要 build，所以把它们换成 no-op stub。
set -euo pipefail

RUBY="${RUBY:-/usr/bin/ruby}"
BIN="$HOME/.gem/ruby/2.6.0/bin"
STUB="$HOME/.gem/jekyll-stubs"

"$RUBY" -v

echo "== 纯 ruby 依赖 =="
gem install --user-install --no-document \
  public_suffix:4.0.7 addressable:2.8.1 colorator:1.1.0 i18n:0.9.5 \
  kramdown:1.17.0 kramdown-parser-gfm:1.1.0 liquid:4.0.4 mercenary:0.3.6 \
  pathutil:0.16.2 rouge:3.30.0 safe_yaml:1.0.5

echo "== jekyll 本体（不解析依赖） =="
gem install --user-install --ignore-dependencies --no-document \
  jekyll:3.9.5 jekyll-paginate:1.1.0 jekyll-sass-converter:1.5.2 sass:3.7.4

echo "== stub gem（只为让 RubyGems 激活依赖，构建用不到） =="
mkdir -p "$STUB/em-websocket/lib" "$STUB/jekyll-watch/lib" "$STUB/sass-listen/lib"

cat > "$STUB/em-websocket/lib/em-websocket.rb" <<'RUBY'
module EventMachine
  def self.run(&_blk); end
  class Connection; end
end
module EventMachine
  module WebSocket
    def self.start(*); raise NotImplementedError, "em-websocket stub"; end
  end
end
RUBY

cat > "$STUB/jekyll-watch/lib/jekyll-watch.rb" <<'RUBY'
module Jekyll
  module Watcher
    def self.watch(_options = {}); end
  end
end
RUBY

cat > "$STUB/sass-listen/lib/sass-listen.rb" <<'RUBY'
module Sass
  module Listen
    def self.start(*); raise NotImplementedError, "sass-listen stub"; end
  end
end
RUBY

stub_gem() {
  local name="$1" version="$2"
  (
    cd "$STUB/$name"
    cat > "$name.gemspec" <<RUBY
Gem::Specification.new do |s|
  s.name = "$name"
  s.version = "$version"
  s.summary = "local stub for jekyll build"
  s.authors = ["local"]
  s.license = "MIT"
  s.files = ["lib/$name.rb"]
end
RUBY
    gem build -q "$name.gemspec" >/dev/null
    gem install --user-install --no-document "./$name-$version.gem" 2>&1 | tail -1
  )
}

stub_gem em-websocket 0.5.3
stub_gem jekyll-watch 2.2.1
stub_gem sass-listen 4.0.0

echo "== 验证 =="
"$BIN/jekyll" -v
echo "ok：现在可以 ./deploy.sh --build"
