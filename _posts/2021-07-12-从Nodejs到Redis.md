--- 
layout: post
date: 2021-11-12 23:30
category: 并发编程
tags:
  - Node.js
  - Redis
--- 

### 从单线程模型说起

#### 真的只是单线程吗?

我们知道 Node.js 和 Redis 都是部分基于**单线程**模型的。

具体来说, Node.js 只有一个 JavaScript 线程，但是在libuv中仍然存在多个I/O线程。

而 Redis 对核心网络模型和键值的读写是单线程的。Redis v4.0 为了解决删除超大的键值对引起的阻塞问题，引入多线程处理异步任务。Redis v6.0 正式在网络模型中实现 I/O 多线程， 不过只负责网络 I/O 和命令解析部分，命令执行部分仍然是由主线程处理的，目的是解决Redis  的网络 I/O 瓶颈。

#### 并行处理请求工作的方式

我们同时也知道现代 Web 应用中，并发是必须提供的能力，也就是说必须尽可能的减少阻塞。

常见的并行处理请求工作的方式有：

1. **多进程方式**。为每个请求启动一个进程，但是因为系统资源有限，不具有扩展性。如初期的 Apache就采用了这种方式。 
2. **多线程方式**。为每个请求启动一个线程，虽然线程比进程要轻量，但是大并发请求到来时，资源还是很快用尽，导致服务缓慢。 IIS 服务器采用的是这种方式，所以IIS 会定期重启服务。
3. **异步方式。**发送方发出一个请求后，不等待接收方响应这个请求，就继续发送下一个请求。

#### 为什么它们采用了单线程模型呢？

从**实际场景**来说：

Node.js要保持 JavaScript 在浏览器中单线程的特点采用了单线程模型。

而对于Redis 来说，CPU 通常不会是瓶颈，因为大多数请求不会是 CPU 密集型的，而是 I/O 密集型。如果不考虑 RDB/AOF 等持久化方案，Redis 是完全的纯内存操作，执行速度是非常快的。Redis 真正的性能瓶颈在于网络 I/O，也就是客户端和服务端之间的网络传输延迟，因此 Redis 选择了单线程的 I/O 多路复用来实现它的核心网络模型。

从**单线程的好处**来说：

单线程避免了过多的上下文切换。多线程调度过程中必然需要在 CPU 之间切换线程上下文 context，而上下文的切换又涉及程序计数器、堆栈指针和程序状态字等一系列的寄存器置换、程序堆栈重置甚至是 CPU 高速缓存、TLB 快表的汰换。

单线程也避免了同步机制的开销，只有一个线程就不用考虑锁的问题。

写出来的代码简单可维护。这也是Redis的作者一直秉承的理念。

### 单线程模型下如何处理并发请求

I/O是昂贵的，分布式I/O则是更昂贵的。幸好，在计算机资源中，I/O与CPU计算之间是可以并行进行的。

通过引入 **异步I/O** 让单线程远离阻塞，从而更好的利用CPU。

#### 操作系统对I/O的支持

操作系统提供了阻塞/非阻塞I/O，阻塞I/O造成CPU等待浪费，非阻塞带来的麻烦是需要轮询确认I/O完成的状态，也是对CPU资源的浪费,但是非阻塞I/O比阻塞I/O相对资源利用率会高一些。

操作系统提供了I/O的系统调用有

##### 同步非阻塞I/O:

- **read** 通过**重复调用**来检查I/O的状态，CPU一直耗用在等待上。

- **select** 采用了**数组** `fd_set` 表示文件描述符, 存在最大文件描述符数量限制。且每次调用都需要把 fd 集合从用户态拷贝到内核态。

- **poll** 用**链表** `pollfd` 的方式解决了最大文件描述符数量限制。

- **epoll** 则不需要遍历，采用的是**回调机制**，通过三个系统调用

  - **epoll_create** 创建一个 epoll 实例并返回 `epollfd`
  - **epoll_ctl** 注册文件描述符等待的 I/O 事件(比如 EPOLLIN、EPOLLOUT 等) 到 epoll **红黑树**实例上
  - **epoll_wait** 则是阻塞监听 epoll 实例上所有的文件描述符的 I/O 事件，它接收一个用户空间上的一块内存地址 (events 数组)，kernel 会在有 I/O 事件发生的时候把文件描述符列表复制到这块内存地址上，然后 epoll_wait 解除阻塞并返回，最后用户空间上的程序就可以对相应的 fd 进行读写了。

  epoll的优势在于分清了高频调用和低频调用，直接返回已就绪 fd，并减少了数据在用户态和内核态之间的复制。

##### 异步非阻塞I/O:

通过信号和回调来传递数据

- **iocp**@windows  线程池
- **aio**@linux  存在缺陷，只支持DIRECT_I/O，无法利用系统缓存

由于操作系统对异步I/O支持的不全面，所以实际上是让部分线程进行I/O加轮询来完成数据获取，让另一个线程进行计算处理，通过线程之间的通信进行数据传递，来模拟实现异步I/O。

#### Reactor 和 Proactor 设计模式

##### 基于「事件分发」的网络编程模式

前面的同步/异步非阻塞I/O 是内核提供给用户态的多路复用系统调用，线程可以通过一个系统调用函数从内核中获取多个事件。但这种方式是面向过程的，基于面向对象的思想，大佬们对 I/O 多路复用作了一层**事件驱动**的封装，让使用者不用考虑底层网络 API 的细节，只需要关注应用代码的编写。

根据I/O类型的不同类型又可以分为 `Reactor` 模式 和 `Proactor` 模式。

##### Reactor 模式

Reactor 模式也叫 `Dispatcher` 模式。**同步非阻塞的I/O 多路复用监听事件，收到事件后，根据事件类型分配（Dispatch）给某个进程 / 线程**。

工作流程为:

- Reactor 对象通过 I/O 多路复用接口监听事件，收到事件后通过 dispatch 进行分发，具体分发给 Acceptor 对象还是 Handler 对象，还要看收到的事件类型；

- 如果是连接建立的事件，则交由 Acceptor 对象进行处理，Acceptor 对象会通过 accept 方法 获取连接，并创建一个 Handler 对象来处理后续的响应事件；

- 如果不是连接建立事件， 则交由当前连接对应的 Handler 对象来进行响应。Handler 对象通过 read -> 业务处理 -> send 的流程来完成完整的业务流程。

##### Proactor 模式

先讲一下两个模式的区别

- **Reactor 是非阻塞同步网络模式，感知的是就绪可读写事件**。在每次感知到有事件发生（比如可读就绪事件）后，就需要应用进程主动调用 read 方法来完成数据的读取，也就是要应用进程主动将 socket 接收缓存中的数据读到应用进程内存中，这个过程是同步的，读取完数据后应用进程才能处理数据。
- **Proactor 是异步网络模式， 感知的是已完成的读写事件**。在发起异步读写请求时，需要传入数据缓冲区的地址（用来存放结果数据）等信息，这样系统内核才可以自动帮我们把数据的读写工作完成，这里的读写工作全程由操作系统来做，并不需要像 Reactor 那样还需要应用进程主动发起 read/write 来读写数据，操作系统完成读写工作后，就会通知应用进程直接处理数据。

因此，**Reactor 可以理解为「来了事件操作系统通知应用进程，让应用进程来处理」**，而 **Proactor 可以理解为「来了事件操作系统来处理，处理完再通知应用进程」**。

Proactor工作流程为:

- Proactor Initiator 负责创建 Proactor 和 Handler 对象，并将 Proactor 和 Handler 都通过 Asynchronous Operation Processor 注册到内核；

- Asynchronous Operation Processor 负责处理注册请求，并处理 I/O 操作；

- Asynchronous Operation Processor 完成 I/O 操作后通知 Proactor；

- Proactor 根据不同的事件类型回调不同的 Handler 进行业务处理；

- Handler 完成业务处理

可惜的是，在 Linux 下的异步 I/O 是不完善的， `aio` 系列函数是由 POSIX 定义的异步操作接口，不是真正的操作系统级别支持的，而是在用户空间模拟出来的异步，并且仅仅支持基于本地文件的 aio 异步操作，网络编程中的 socket 是不支持的，这也使得基于 Linux 的高性能网络程序都是使用 Reactor 方案。

#### Node.js 的异步机制

Node异步模型的基本要素包括 **事件循环**，**观察者**，**请求对象**，**I/O线程池**。

可以认为 Node.js 的异步机制也是 Reator 模式的一个应用，事件循环相当于 Reactor， I/O 线程池相当于 Handler。

Node的事件循环机制底层是通过 **libuv** 来实现的。

##### 事件循环

在进程启动的时候，Node就会创建一个循环，每执行一次循环体的过程被称为Tick。每个Tick的过程就是查看是否有事件待处理，如果有，就取出其中事件和对应的回调函数进行执行。

```
   ┌───────────────────────────┐
┌─>│           timers          │
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │     pending callbacks     │
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │       idle, prepare       │
│  └─────────────┬─────────────┘      ┌───────────────┐
│  ┌─────────────┴─────────────┐      │   incoming:   │
│  │           poll            │<─────┤  connectI/Ons, │
│  └─────────────┬─────────────┘      │   data, etc.  │
│  ┌─────────────┴─────────────┐      └───────────────┘
│  │           check           │
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
└──┤      close callbacks      │
   └───────────────────────────┘
```

**timer** 阶段主要是处理定时器相关的任务，如 settimeout/setInterval。

**pending callbacks**  阶段主要是处理 poll I/O 阶段回调里产生的回调。

**idle, prepare** 阶段是自定义的阶段。

**poll** 阶段主要检索新的 I/O 事件;执行与 I/O 相关的回调（几乎所有情况下，除了关闭的回调函数，那些由计时器和 `setImmediate()` 调度的之外），其余情况 node 将在适当的时候在此阻塞

**check** 阶段包括 `setImmediate()` 回调函数

**close callbacks**  一些关闭的回调函数，如：`socket.on('close', ...)`。

**process.nextTick** 从技术上讲不是事件循环的一部分。不管事件循环的当前阶段如何,它都将在当前操作完成后处理 `nextTickQueue`。

##### 观察者

前面的每个阶段也就是观察者，用来判断是否有事件要处理。

包括 idle 观察者， I/O 观察者，check 观察者。

##### 请求对象

从JavaScript发起调用到内核执行完I/O操作的过度过程中的中间产物。

也包含了提交给libuv的参数和libuv执行完以后的回调函数。

##### I/O线程池

用于处理实际的I/O操作。windows下由内核IOCP直接提供，*nix下由libuv自行实现。

#### Redis 的 Reactor 设计模式

Redis4.0 前的网络模型是比较典型的单线程单 Reactor 模式。

Redis自己实现了事件轮询器 AE 对应 Reactor，主线程负责执行命令相当于 Handler。

Redis v6.0 正式在网络模型中实现 I/O 多线程， 不过只负责网络 I/O 和命令解析部分，也就相当于部分工作交给了多个Handler。

[核心数据结构](https://github.com/huangz1990/redis-3.0-annotated/blob/8e60a75884e75503fb8be1a322406f21fb455f67/src/ae.c)如下:

```c
/* State of an event based program 
 *
 * 事件处理器的状态
 */
typedef struct aeEventLoop {

    // 目前已注册的最大描述符
    int maxfd;   /* highest file descriptor currently registered */

    // 目前已追踪的最大描述符
    int setsize; /* max number of file descriptors tracked */

    // 用于生成时间事件 id
    long long timeEventNextId;

    // 最后一次执行时间事件的时间
    time_t lastTime;     /* Used to detect system clock skew */

    // 已注册的文件事件
    aeFileEvent *events; /* Registered events */

    // 已就绪的文件事件
    aeFiredEvent *fired; /* Fired events */

    // 时间事件
    aeTimeEvent *timeEventHead;

    // 事件处理器的开关
    int stop;

    // 多路复用库的私有数据
    void *apidata; /* This is used for polling API specific data */

    // 在处理事件前要执行的函数
    aeBeforeSleepProc *beforesleep;

} aeEventLoop;
```

注意这里并没有和事件一一对应的回调函数，只是因为Redis的功能相对固定，统一将事件交给主线程处理就可以了。

### 单线程的缺点是什么？

- 第一个缺点，因为只有一个进程，**无法充分利用 多核 CPU 的性能**；
- 第二个缺点，Handler 对象在业务处理时，整个进程是无法处理其他连接的事件的，**如果业务处理耗时比较长，那么就造成响应的延迟**；

因此，Node.js 提出来 child_process 和 cluster 的解决方案，而 Redis 则通过集群的方式来扩展其处理能力。

### 参考资料

[Node.js 事件循环，定时器和 `process.nextTick()`](https://nodejs.org/zh-cn/docs/guides/event-loop-timers-and-nexttick/#understanding-process-nexttick)

[高性能网络框架：Reactor 和 Proactor](https://bbs.huaweicloud.com/blogs/266248?utm_source=zhihu&utm_medium=bbs-ex&utm_campaign=other&utm_content=content)

深入浅出Node.js 朴灵