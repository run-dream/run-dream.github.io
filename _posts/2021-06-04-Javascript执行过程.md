---
layout: post
date: 2021-06-04 11:00
category: JavaScript
tags:
  - 作用域
  - 闭包
  - 延迟加载
---



### 问题

写了一段乍看上去没问题的代码

```js
/**
 * @description 遍历数组，求总和
 * @param {*[]} array
 * @param {Function|string} rule
 * @return
 */
function sum(array, rule) {
    if (typeof rule === "string") {
        rule = item => item[rule];
    }
    return array.reduce((result, item) => {
        return result + Number(rule(item) || 0);
    }, 0);
}

```

运行发现只要rule传入string,输出结果永远为0

### 修复

```diff
--- f1 2021-06-04 16:45:41.000000000 +0800
+++ f2 2021-06-04 16:45:51.000000000 +0800
@@ -1,14 +1,15 @@ 
/**
 * @description 遍历数组，求总和
 * @param {*[]} array
 * @param {Function|string} rule
 * @return
 */
 function sum(array, rule) {
     if (typeof rule === "string") {
- 		rule = (item) => item[rule];
+       const field = rule;
+       rule = item => item[field];
     }
     return array.reduce((result, item) => {
         return result + Number(rule(item) || 0);
     }, 0);
 }
 
```

### 原因

我们从函数的执行过程来分析这个问题，当函数运行到 

```javascript
rule = (item) => item[rule]
```

的时候，V8 并不会一次性将所有的 JavaScript 解析为中间代码，更加不会执行，而只是将该函数声明转换为函数对象。到具体执行函数的时候，才会根据作用域链去查找rule的变量。如果将rule改写成

```javascript
rule = item => {
    console.log(typeof rule);
    return item[rule]
}
```

此时会输出 function. 即 rule 已经在前面的执行过程中变成了 function 类型。 而 item[function(){}] 的值 为 undefined，从而无论输入是什么，函数都会返回0；

而修改是将field作为rule函数外部的一个变量，利用闭包的性质可以访问到这个不变的值。

### 扩展

- 作用域链

  作用域链就是将一个个作用域串起来，实现变量查找的路径。作用域就是存放变量和函数的地方。

  - 全局作用域

    存放了全局变量和全局函数。全局作用域是在 V8 启动过程中就创建了，且一直保存在内存中不会被销毁的，直至 V8 退出。

  - 函数作用域

    存放了函数中定义的变量。而函数作用域是在执行该函数时创建的，当函数执行结束之后，函数作用域就随之被销毁掉了。

- [闭包](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Closures)

  一个函数和对其周围状态（**lexical environment，词法环境**）的引用捆绑在一起（或者说函数被引用包围），这样的组合就是**闭包**（**closure**）。三个基础特性：

  1. JavaScript 语言允许在函数内部定义新的函数
  2. 可以在内部函数中访问父函数中定义的变量
  3. 因为函数是一等公民，所以函数可以作为返回值

- [惰性解析](https://time.geekbang.org/column/article/223168)

  V8 执行 JavaScript 代码，需要经过编译和执行两个阶段，其中编译过程是指 V8 将 JavaScript 代码转换为字节码或者二进制机器代码的阶段，而执行阶段则是指解释器解释执行字节码，或者是 CPU 直接执行二进制机器代码的阶段。我们熟悉的AST和变量提升其实是在编译过程中做的事情。

  在编译 JavaScript 代码的过程中，V8 并不会一次性将所有的 JavaScript 解析为中间代码。所谓惰性解析是指解析器在解析的过程中，如果遇到函数声明，那么会跳过函数内部的代码，并不会为其生成 AST 和字节码，而仅仅生成顶层代码的 AST 和字节码。