## 介绍
Run-dream 的 Github Blog

## 本地构建与发布

这个仓库同时是站点源文件和部署工具所在处，线上站点是 **https://rundream.cn**（阿里云主机静态托管）。

```bash
./setup-gems.sh            # 一次性：本机装 jekyll 3.9.5（macOS 系统 ruby 的 stub gem 绕法）
./deploy.sh --build        # 只构建到 ./dist
./deploy.sh                # 构建 + rsync 到 openclaw:/srv/blog（全站）
./deploy.sh --subset       # 只发读书笔记 + 2025 年后（历史口径）
```

`deploy.sh` 会：

1. 把仓库复制到 `.build/site`，按需剔除文章；
2. 把文中指向 `run-dream.github.io` 的绝对图片地址改写成站内根路径；
3. 扫描内网痕迹（`*.netease.com`、内网网段等），命中即中止；
4. 用 `_config.yml` + `.build/aliyun.yml`（`url: https://rundream.cn`、`baseurl: ""`）构建；
5. `rsync -az --delete` 到主机 `/srv/blog`。

GitHub Pages 仍在发布，作为海外镜像；主站以 `rundream.cn` 为准。
nginx 配置在 `~/dev/aliyun/nginx/rundream.conf`。

## 致谢

1. 这个模板是从这里 [qiubaiying](https://github.com/qiubaiying/qiubaiying.github.io) fork 的, 感谢作者。
2. 感谢 [Hux](https://github.com/Huxpro/huxpro.github.io) 提供的模版




