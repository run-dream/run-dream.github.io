---
layout: post
date: 2020-12-03 16:00:00
category: VSCode
tags:
  - VSCode
  - Java
---

### 背景
临时要改一段JavaSpring代码,但外网机上只有VSCode，懒得安装Eclipse(我就是嫌弃它太重了)，买不起IntelliJ IDEA。于是尝试用VSCode来进行开发。
### 步骤
1. 安装Java
   VSCode识别出Java文件后会弹出一段下载的地址,点击后调到github下载，下载速度令人抓狂。
   改到从[清华大学开源软件镜像站](https://mirrors.tuna.tsinghua.edu.cn/AdoptOpenJDK/)国内镜像下载
2. 安装Maven
   [Maven](https://www.runoob.com/maven/maven-tutorial.html)安装包比较小，可以直接从[官方网站](http://maven.apache.org/download.cgi)下载
   解压 配置环境变量
3. 安装VSCode插件
   简单来说直接使用[Java Extension Pack](https://marketplace.visualstudio.com/items?itemName=vscjava.vscode-java-pack)
   它是微软官方集成的若干个插件的集合
   ![Java Extension Pack](https://run-dream.github.io/img/post/vscode-java-pack.png)
4. 愉快的修改代码