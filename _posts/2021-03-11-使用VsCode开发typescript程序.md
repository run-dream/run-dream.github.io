---
layout: post
date: 2021-03-11 10:00:00
category: VSCode
tags:
  - VSCode
  - Typescript
---

### 一. 安装[typescript](https://github.com/microsoft/TypeScript)
``` bash
npm install -g typescript
```

Typescript是JavaScript的超集。typescript提供了tsc的指令来将ts文件编译成js文件

添加对node核心包的描述

```bash
npm install -D @types/node
```

ps：

如果不希望全局安装，也可以使用

```bash
npm install -D typescript
```

然后使用[npx](https://github.com/npm/npx) 来调用项目内部安装的模块

### 二. 新建typescript项目

1.  初始化 package.json

   ```bash
   npm init -y
   ```

2. 初始化 tsconfig.json

   ```bash
   tsc init
   ```

   可以通过修改outDir来指定编译生成的js文件存放目录

3.  普通的运行

   ```bash
   tsc 
   node ./dist/index.js
   ```


### 三. 使用[ts-node](https://github.com/TypeStrong/ts-node) 

普通运行每次都要编译，太麻烦了。

ts-node 是通过源代码映射来执行ts代码，并提供了REPL环境

- 安装

  ```
  npm install -g ts-node
  ```

- 使用

  REPL

  ```bash
  ts-node
  ```

  运行ts文件

  ```bash
  ts-node index.ts
  ```

### 四. 代码检查 Eslint

**TSLint官方推荐使用ESLint**

1. 安装

   ```bash
   npm install eslint --save-dev
   ```

2. 配置

   ```bash
   npx eslint --init
   ```

   选择standard

3. 集成

   打开VSCode，文件 => 首选项 => 设置 添加

   ```json
   {
     "eslint.validate": [
       "typescript"
     ]
   }
   ```



### 五. 使用VSCode调试

添加.vscode/launch.json

```json
{
  // 使用 IntelliSense 了解相关属性。 
  // 悬停以查看现有属性的描述。
  // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Launch Program",
      "runtimeArgs": [
        "-r",
        "ts-node/register"
      ],
      "args": [
        "${workspaceFolder}/src/index.ts"
      ]
    }
  ]
}

```

即可 F5调试



### 六. 使用[ts-mocha]([github.com/piotrwitek/ts-mocha](https://github.com/piotrwitek/ts-mocha))来进行单元测试

1. 安装

   ```bash
   npm install -D mocha
   npm install -D ts-mocha
   npm install -D @types/mocha
   ```

2. 编写.test.ts

3. 测试

   ```bash
   npx ts-mocha ./src/test/*.test.ts
   // OR
   npx mocha -r ts-node/register ./src/test/*.test.ts
   ```
