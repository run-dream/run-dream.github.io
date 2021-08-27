---
layout: post
date:       2021-08-27 20:00:00
category: Algorithm
title: 从1到k推广股票交易问题
tags:
    - Algorithm
    - LeetCode
    - DynamicPlaning
---



## 背景

LeetCode 上有一系列的 股票交易 的问题， 列举如下：

1. [一次交易](https://leetcode.com/problems/best-time-to-buy-and-sell-stock/) (Easy)
2. [无数次交易](https://leetcode.com/problems/best-time-to-buy-and-sell-stock-ii/) (Easy)
3. [两次交易](https://leetcode.com/problems/best-time-to-buy-and-sell-stock-iii/) (Hard)
4. [K次交易](https://leetcode.com/problems/best-time-to-buy-and-sell-stock-iv/) (Hard)

是用来学习**动态规划**的很好的案例。



## 分析和实现

### 一次交易

很容易想到一次买，一次卖。要求的结果，就是在第i天买入的最大收益，也就是要找到第i天以后的最高价位。

自然可以想到暴力求解，对于每天都去找后面的最大值。在这个过程中，我们注意到存在重复计算，存在优化空间，可以先一次遍历找出每个位置后的最大值。时间复杂度 O(n) 。代码如下:

``` go
func maxProfit(prices []int) int {
    if len(prices) <= 1{
        return 0
    }
    solds := make([]int, len(prices))
    solds[len(prices)-1] = prices[len(prices)-1]
    for i := len(prices) - 2; i >= 0; i --{
        solds[i] = max(prices[i], solds[i+1])
    }
    profit := 0
    for i := 0; i < len(prices); i ++{
        profit = max(profit, solds[i] - prices[i])
    }
    return profit
}

func max(a, b int) int {
    if a > b {
        return a
    }
    return b
}
```

这里需要两次遍历一个数组，而且要保存一个长度为n的数组，但是这个数组的每个值实际上只用了一次，可以进行压缩。

``` go
func maxProfit(prices []int) int {
    if len(prices) <= 1{
        return 0
    }
    highest := prices[len(prices)-1]
    profit := 0
    for i := len(prices) - 2; i >= 0; i --{
        profit = max(profit, highest - prices[i])
        if highest < prices[i] {
            highest = prices[i]
        }
    }
    return profit
}
```



### 无数次交易

其实只要想到无数次交易，每次股票下跌去前就卖掉，每次要上涨就买入，就可以获取到所有上升的收益。

这里是用的**贪心**的算法。

```go
func maxProfit(prices []int) int {
	profix := 0
	for i := 1; i < len(prices); i++ {
		if prices[i] > prices[i-1] {
			profix += prices[i] - prices[i-1]
		}
	}
	return profix
}

```



## 二次交易

首先按照暴力的思想来做，将时间段分成两段，然后按照一次交易去处理，最后按照分割点求最大值。时间复杂度 

为 O(n * n)。

注意，题目中说是**最多2次**，而不是一共两次。

``` go
func maxProfit(prices []int) int {
    result := 0
    for i := 0; i < len(prices);i++{
        result = max(result, maxProfit1(prices[0:i]) + maxProfit1(prices[i:]))
    }
    return result
}

func maxProfit1(prices []int) int {
    if len(prices) <= 1{
        return 0
    }
    highest := prices[len(prices)-1]
    profit := 0
    for i := len(prices) - 2; i >= 0; i --{
        profit = max(profit, highest - prices[i])
        if highest < prices[i] {
            highest = prices[i]
        }
    }
    return profit
}

func max(a, b int) int {
    if a > b {
        return a
    }
    return b
}
```

在LeetCode上提交会超时。注意到计算 maxProfit1 的时候有很多重复计算的部分，这里也许可以优化。但是比较麻烦。

然后想想是不是可以用动态规划的方式来解决这个问题。首先，需要定义题目中出现的状态和选择。

选择就是在第i天是否操作，操作可以分为买入或者卖出，当然不能在手头没有股票的情况下卖出。

那么状态就是 天数，操作的次数，以及手头是否持有股票。我们注意到其实可以通过交易的次数来确定手头是否持有股票。

如果记 `dp[i][j]` 为 第 i 天， 交易 j 次以后的最大收益，我们最后要求的值就是 `max(dp[n][j]), 0 <= j <= 4)`,动态规划方程为:

`dp[i][j] = max(dp[i-1][j], dp[i-1][j+1] + benifit) , ` 0 <= j <= 4  

其中 `benifit = prices[i] if j % 2 == 0 else - prices[i]`

注意，在开始计算之前，需要处理一下不可能出现结果的情况，也就是 j >= i 。

``` go
func maxProfit(prices []int) int {
    dp := make([][]int, len(prices) + 1)
    for i := 0; i <= len(prices);i++{
        dp[i] = make([]int, 5)
        for j := 0; j < 5;j++{
            if j > i {
                dp[i][j] = -1E5 -1 // 表示不可达
            }            
        }
    }
    for i := 1; i <= len(prices); i++{
        for j := 1; j < 5; j ++{
            benifit := prices[i-1]
            if j % 2 == 1{
                benifit = -prices[i-1]
            }
            dp[i][j] = max(dp[i-1][j], dp[i-1][j-1] + benifit)
        }
    }
    result := 0
    for i := 1; i < 5; i ++{
        result = max(result, dp[len(prices)][i])
    }
    return result
}

func max(a, b int) int {
    if a > b {
        return a
    }
    return b
}
```



###  K 次交易

按照前面的思路，把 5 改成 2 * k + 1 即可。

``` go
func maxProfit(k int, prices []int) int {
    dp := make([][]int, len(prices) + 1)
    for i := 0; i <= len(prices);i++{
        dp[i] = make([]int, 2 * k + 1)
        for j := 0; j < 2 * k + 1;j++{
            if j > i {
                dp[i][j] = -1E5 -1 // 表示不可达
            }            
        }
    }
    for i := 1; i <= len(prices); i++{
        for j := 1; j <  2 * k + 1; j ++{
            benifit := prices[i-1]
            if j % 2 == 1{
                benifit = -prices[i-1]
            }
            dp[i][j] = max(dp[i-1][j], dp[i-1][j-1] + benifit)
        }
    }
    result := 0
    for i := 1; i <  2 * k + 1; i ++{
        result = max(result, dp[len(prices)][i])
    }
    return result
}

func max(a, b int) int {
    if a > b {
        return a
    }
    return b
}
```

