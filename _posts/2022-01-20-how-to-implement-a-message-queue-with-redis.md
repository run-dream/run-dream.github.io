---
layout: post
date:       2022-01-20 08:00:00
category:  Redis
title:  如何基于 Redis 实现一个消息队列
tags:
    - bull
    - Redis
    - MessageQueue
---

### 需求背景

Kafka RoundRobin 不保证消息全局顺序一致性 而业务依赖特定事件 

业务上也要求延迟处理。（这个可以在返回数据时控制）

引入 延迟队列。

[kafka 实现延迟队列](https://juejin.cn/post/6961633277199253534)

### 消息队列的基本要求
可靠性

### 如何实现
1. 生产阶段
2. 存储阶段
3. 消费阶段

### 重复消费的处理
1. At most once  消息在传递时，最多会被送达一次。换一个说法就是，没什么消息可靠性保证，允许丢消息。
2. At least once 至少一次。消息在传递时，至少会被送达一次。也就是说，不允许丢消息，但是允许有少量重复消息出现。(幂等)
3. Exactly once  恰好一次。消息在传递时，只会被送达一次，不允许丢失也不允许重复，这个是最高的等级。

#### 最基础的实现
redis 和相关的方法
- BLPOP  / RPUSH
- PUB / SUB
- Redis Stream XADD  XREADGROUP  XACK 
 
#### 存在的问题
- 出错重试 
- 消费积压 （性能优化, 监控扩容）
- 高可用 (redis-cluster Redis主从复制)

### BullMQ
### 简介
BullMQ 实现了以下特性:

- 由于无轮询设计，CPU使用率最低
- 基于Redis的分布式作业执行
- LIFO 和 FIFO 的作业
- 优先级
- 延迟作业
- 基于 cron 规范的计划和可执行作业
- 失败作业的重试
- 每个工作进程的并发设置
- 线程（沙盒）处理函数
- 从进程崩溃中自动恢复
### 使用
Producer:
``` typescript
import { Queue } from 'bullmq'

const myQueue = new Queue('Paint');

// Add a job that will be processed after all others
await myQueue.add('wall', { color: 'pink' });
```

Consumer:

``` typescript
myQueue.process(async function (job, done) {
  await someFunc(job);
});
```
### 实现
#### 结构：
![img](https://run-dream.github.io/img/post/bull-job-lifecycle.png)

#### 运行时Redis的情况:
![img](https://run-dream.github.io/img/post/bull-add.png)
![img](https://run-dream.github.io/img/post/bull-job.png)

#### Tips
1. 原子性 所以需要lua脚本执行 
2. lua 脚本 -> apiPrefix 使用 {hashtag} 

#### 源码里定义的脚本

```
.
├── addJob-6.lua
├── cleanJobsInSet-3.lua
├── extendLock-2.lua
├── index.js
├── isFinished-2.lua
├── isJobInList-1.lua
├── moveStalledJobsToWait-7.lua
├── moveToActive-8.lua
├── moveToDelayed-3.lua
├── moveToFinished-8.lua
├── obliterate-2.lua
├── pause-5.lua
├── promote-4.lua
├── releaseLock-1.lua
├── removeJob-10.lua
├── removeJobs-8.lua
├── removeRepeatable-2.lua
├── reprocessJob-4.lua
├── retryJob-3.lua
├── takeLock-1.lua
├── updateDelaySet-6.lua
└── updateProgress-2.lua
``` 

### 一个 Job 到底是怎么生成和消费的
- addJob
- moveToActive/ moveToDelayed
- moveToFinished moveToFail