---
layout: post
date:       2022-03-13 22:00:00
category:  Redis
title:  Redis 集群
tags:
    - Redis
    - predixy
---

### 为什么 Redis 需要集群化
每时每刻都拥有非常大的写入量的情况下，此时如果只有一个主节点是无法承受的。
这就需要集群化！简单来说实现方式就是，多个主从节点构成一个集群，每个节点存储一部分数据，这样写请求也可以分散到多个主节点上，解决写压力大的问题。同时，集群化可以在节点容量不足和性能不够时，动态增加新的节点，对进群进行扩容，提升性能。

### 有哪些方案
为了实现集群的功能，从服务端、客户端分片的角度来看，可以分为以下三类：

#### 客户端分片

##### 实现原理

把分片的逻辑放在Redis客户端实现，通过Redis客户端预先定义好的路由规则(使用一致性哈希)，把对Key的访问转发到不同的Redis实例中，查询数据时把返回结果汇集。

##### 解决方案

支持一致性哈希的客户端，如 ShardedJedis

##### 优点

所有的逻辑都是可控的，不依赖于第三方分布式中间件

##### 缺点

1. 静态的分片方案，需要增加或者减少Redis实例的数量，需要手工调整分片的程序。
2.  运维成本比较高，集群的数据出了任何问题都需要运维人员和开发人员一起合作，减缓了解决问题的速度，增加了跨部门沟通的成本。
3. 在不同的客户端程序中，维护相同的路由分片逻辑成本巨大

#### 代理分片

##### 实现原理

通过中间件的形式，Redis客户端把请求发送到代理，代理根据路由规则发送到正确的Redis实例，最后代理把结果汇集返回给客户端。

##### 方案

主流的代理包含：predixy、twemproxy、codis、redis-cerberus四款。

| **特性**               | **predixy**                                           | **twemproxy** | **codis**      | **redis-cerberus**      |
| ---------------------- | ----------------------------------------------------- | ------------- | -------------- | ----------------------- |
| 高可用                 | Redis Sentinel或Redis Cluster                         | 一致性哈希    | Redis Sentinel | Redis Cluster           |
| 可扩展                 | Key哈希分布或Redis Cluster                            | Key哈希分布   | Key哈希分布    | Redis Cluster           |
| 开发语言               | C++                                                   | C             | GO             | C++                     |
| 多线程                 | 是                                                    | 否            | 是             | 是                      |
| 事务                   | Redis Sentinel模式单Redis组下支持                     | 不支持        | 不支持         | 不支持                  |
| BLPOP/BRPOP/BLPOPRPUSH | 支持                                                  | 不支持        | 不支持         | 支持                    |
| Pub/Sub                | 支持                                                  | 不支持        | 不支持         | 支持                    |
| Script                 | 支持load                                              | 不支持        | 不支持         | 不支持                  |
| Scan                   | 支持                                                  | 不支持        | 不支持         | 不支持                  |
| Select DB              | 支持                                                  | 不支持        | 支持           | Redis Cluster只有一个DB |
| Auth                   | 支持定义多个密码，给予不同读写及管理权限和Key访问空间 | 不支持        | 同redis        | 不支持                  |
| 读从节点               | 支持，可定义丰富规则读指定的从节点                    | 不支持        | 支持，简单规则 | 支持，简单规则          |
| 多机房支持             | 支持，可定义丰富规则调度流量                          | 不支持        | 有限支持       | 有限支持                |
| 统计信息               | 丰富                                                  | 丰富          | 丰富           | 简单                    |

在功能的对比上，predixy相比另外三款代理更为全面，基本可以完全适用原生redis的使用场景。

在性能上，predixy在各轮测试中都以较大优势领先，参考：https://github.com/joyieldInc/predixy/wiki/Benchmark

##### 优点

隐藏了背后真正的 Redis 集群，减轻了使用者的心智负担

##### 缺点

不支持所有 Redis 的原生命令，尤其是 Redis 5.0 以后推出来的 Stream 结构的命令，如 xadd。

#### 服务端分片

##### 实现原理

Redis Cluster是一种服务器Sharding技术(分片和路由都是在服务端实现)，**采用多主多从，每一个分区都是由一个Redis主机和多个从机组成，片区和片区之间是相互平行的**。引入了slot的概念，不过redis cluster有16384个slot。redis cluster自身集成了高可用的功能，可扩展也是通过迁移slot来实现的。在请求响应上带来了***MOVE/ASK***语义。

##### 方案

Redis Cluster

##### 优点

原生支持 完全去中心化

##### 缺点

之前的redis客户端无法直接获得全部集群功能，需要增加对MOVE/ASK响应的支持才可以访问整个集群。

### Predixy 使用和配置

#### 安装 Redis

注意 redis cluster 至少要求有6个实例，三主个节点，三个从节点。建议在本地直接使用 docker 来处理。

参考: [Docker搭建Redis Cluster集群](https://cloud.tencent.com/developer/article/1838120)

#### 安装 Predixy

参考:  [Redis主从集群+哨兵搭建实战](https://www.modb.pro/db/64647) 




### 参考资料
[Redis 集群化方案对比：Codis、Twemproxy、Redis Cluster](https://segmentfault.com/a/1190000040083625)
[Redis主从集群+哨兵搭建实战](https://www.modb.pro/db/64647)

[吃透Redis系列（九）：Redis代理twemproxy和predixy详细介绍](https://blog.csdn.net/u013277209/article/details/112895475)