---
layout: post
date:       2021-10-26 20:00:00
category:  git 
title: 如何同时使用 gitlab 和 github 的 ssh 认证
tags:
    - git
    - ssh
---



### 背景

工作环境用 gitlab，自己平时用 github，有时候想用 github 做一些笔记。两个系统的账号不一致。

### 方案

在 ~/.ssh/ 目录下添加 config 文件：

``` config
Host github.com
HostName github.com
User xxx
IdentityFile ~/.ssh/github_id_rsa

Host company
HostName gitlab.com
User xxx
IdentityFile ~/.ssh/id_rsa
```

