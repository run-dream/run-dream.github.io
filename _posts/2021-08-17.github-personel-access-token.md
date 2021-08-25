---
layout: post
date:       2021-08-16 20:00:00
category: git
title: 解决 git push 403 的问题
tags:
    - github
    - git
    - personal access token 
---


## 背景
早上 `git push` 代码的时候发现推送失败, 错误信息如下：
```
remote: Support for password authentication was removed on August 13, 2021. Please use a personal access token instead.
remote: Please see https://github.blog/2020-12-15-token-authentication-requirements-for-git-operations/ for more information.
fatal: unable to access 'https://github.com/run-dream/leetcode-go.git/': The requested URL returned error: 403
```

原来是 github 移除了密码验证，需要使用新的验证方式来进行验证。

## mac 下的配置

### 升级 git 版本

```bash
brew install git
```

### 安装 gcm

```bash
brew tap microsoft/git
brew install --cask git-credential-manager-core
```

### 重新执行

```bash
git push
```

这个时候会唤醒一个 github.ui，给你两个选项：

#### 浏览器验证
如果选择了这个，直接跳到浏览器授权即可。不过后续可能还会过期重新需要验证。

#### personel-access-token
- 生成 token
  打开 https://github.com/settings/tokens, 进行配置。

- 复制 token 填入框中


### 验证
执行 `git push` 发现已经OK了

### 参考资料

[cache-credentials](https://docs.github.com/en/get-started/getting-started-with-git/caching-your-github-credentials-in-git)

