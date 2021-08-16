---
layout: post
date:       2021-08-10 20:00:00
category: kubenetes
title: kubenetes 入门
tags:
    - kubenetes
---

## kubenetes 是什么

官网定义:

> Kubernetes 是一个可移植的、可扩展的开源平台，用于管理容器化的工作负载和服务，可促进声明式配置和自动化。 

抓去关键信息: **容器化**，**声明式配置**，**自动化**

## 背景和解决的问题

为什么会有这个东西，就要从**部署方式**的变更说起:

- 物理机部署

  缺点：

  - 无法为物理服务器中的应用程序定义资源边界，这会导致**资源分配**问题
  - 资源利用不足, 无法**扩展**
  -  维护许多物理服务器的**成本**很高

- 虚拟机部署

  虚拟化技术允许你在单个物理服务器的 CPU 上运行多个虚拟机（VM）。

  缺点：

  - 虚拟化会损耗性能

- **容器部署**

  容器类似于 VM，但是它们具有被放宽的隔离属性，可以在应用程序之间共享操作系统（OS）。

  由于它们与基础架构分离，因此可以跨云和 OS 发行版本进行**移植**。

  缺点：

  - **隔离**性和**安全**性不如VM

容器部署有三个问题需要解决：

- 扩展
- 故障恢复
- 部署

随着应用规模的扩大，自然就出现了**容器编排**的概念，k8s 就是其中的一种方案。

提供的功能包括:

- **服务发现和负载均衡** Ingress
- **存储编排**  PV, PVC, Storage Class
- **自动部署和回滚** Pod, ReplicaSet, Deploy, StatefulSet
- **自动完成装箱计算** Pod Eviction
- **自我修复** Controller
- **密钥与配置管理** Secret

## 核心概念

和linux 进行对比的图示:

![linux vs k8s](https://run-dream.github.io/img/post/linux-vs-k8s.webp)

### 工作负载

工作负载是在 Kubernetes 上运行的应用程序。 

- Pod

  是一组共享了某些资源的容器组，也是k8s的原子调度单位。

  - 通过 Infra 容器来共享Network Namespace
  - 通过mount同一个Volume来共享宿主机的目录

  容器健康检查和恢复机制也是在Pod上进行支持的。

  探针Probe:

  - livenessProbe（健康检查）
  - readinessProbe (可用检查)

- ReplicaSet

  副本集，由副本数目的定义和一个 Pod 模板组成，受 Deployment 控制器操作。

- DaemonSet

  DaemonSet 可以保证在每个主机节点有且只运行一个Daemon Pod。

- StatefulSet

  对有状态的应用进行部署和管理。

  - 拓扑状态
  - 存储状态

- Job

  离线业务，任务。只运行一次。

- CronJob

  定时任务

### 配置与存储

- Secret

  密钥。是帮你把 Pod 想要访问的加密数据，存放到 Etcd 中。然后，你就可以通过在 Pod 的容器里挂载 Volume 的方式，访问到这些 Secret 里保存的信息了。

- ConfigMap

  配置文件。和Secret类似，不同的是

- PersitentVolumnClaim

  - PVC 描述的，是 Pod 想要使用的持久化存储的属性，比如存储的大小、读写权限等。
  - PV 描述的，则是一个具体的 Volume 的属性，比如 Volume 的类型、挂载目录、远程存储服务器地址等。
  - StorageClass 的作用，则是充当 PV 的模板。并且，只有同属于一个 StorageClass 的 PV 和 PVC，才可以绑定在一起。

### 网络

- Service

  逻辑上的一组 Pod，一种可以访问它们的策略。

  Service 的访问入口，其实就是每台宿主机上由 kube-proxy 生成的 iptables 规则，以及 kube-dns 生成的 DNS 记录。

- CoreDNS

  Kubernetes 集群 DNS。Service 和 Pod 都会被分配对应的 DNS A 记录。

- Ingress

  将 Service 暴露给外界，全局的、为了代理不同后端 Service 而设置的负载均衡服务，是 Kubernetes 项目对“反向代理”的一种抽象。

### 自定义创建

- CRD


## 实战

### 部署

本地测试可以使用[minikube](https://kubernetes.io/zh/docs/tutorials/hello-minikube/)

集群安装可以使用[kubeadm](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/)

### 使用

参考 [kubeadm-workshop](https://github.com/resouer/kubeadm-workshop)

- 应用程序打包成Docker 镜像, 并发布
- 编写 deployment.yaml 
- 执行 `kubectl create -f deployment.yaml`命令
- 编写 service.yaml
- 执行 `kubectl create -f service.yaml`

## 参考资料

[官网](https://kubernetes.io/zh/docs/home/)

[ 深入剖析Kubernetes](https://time.geekbang.org/column/intro/116)

[K8s 原理：Kubernetes 架构解析](https://www.redhat.com/zh/topics/containers/kubernetes-architecture)





