---
layout: post
date:       2018-12-05 13:00:00
category: DataBase
tags:
    - DataBase
---

## 一次简单的SqlServer性能优化

### 背景
服务器： Windows Server 2008R2
数据库： SqlServer 2012
数据量： 主表和关联表均有 几十万条数据  关联表较多
情况： 用户请求较多时，数据库查询出现频繁超时

### 处理步骤
1. 直连服务器
2. 查看CPU和内存的占用率均正常，磁盘IO较高
3. 查看Windows系统日志，排除掉无关错误后，只有SqlServer查询超时的错误信息。
4. 查询SqlServer的运行状况，无异常。增加了SqlServer的最大内存。
5. 对Sql查询语句进行逐句优化。

### 优化点
1. 建立多列索引 增加索引命中率
> 当我们执行查询的时候，只能使用一个索引。如果你有三个单列的索引，MySQL会试图选择一个限制最严格的索引。但是，即使是限制最严格的单列索引，它的限制能力也肯定远远低于三个列上的多列索引。多列索引还有另外一个优点，它通过称为最左前缀的机制可以复用索引。

2. 使用include 避免查询后的Lookup
> 在查询中，我们对返回的列在查询条件上若建立了非聚集索引，此时将可能尝试使用非聚集索引查找，如果返回的列没有创建非聚集索引，此时会返回到数据页中去获取这些列的数据，即使表中存在聚集索引或者没有，都会返回到表中或者聚集索引中去获取数据。对于以上场景描述，如果表没有创建聚集索引则称为Bookmar Lookup，如果表中没有聚集索引但是存在非聚集索引我们称为RID Lookup。

### 操作细节
1. 可以通过以下语句来获取缓存了的且缺少索引的查询的执行计划
``` sql
select top 100 
    last_execution_time, execution_count, statement_start_offset, p.query_plan, q.text
from sys.dm_exec_query_stats
    cross apply sys.dm_exec_query_plan(plan_handle) p
    cross apply sys.dm_exec_sql_text(plan_handle) as q
where last_execution_time > '2019-06-13' and cast(query_plan as nvarchar(max)) like '%Missing Index%'
order by (total_logical_reads + total_logical_writes)/execution_count Desc

```

2. 直接点开query_plan，SqlServer有推荐如何建立索引

### 总结
 产生原因
- 开发时，测试服数据量较小，只对数据表建立了单列索引，没有对具体的Sql语句进行优化和索引设计。上线正式服以后，没有重新建立索引。
- 对SqlServer的索引机制不了解，这也是为何线上出现卡顿后，没有及时进行有效处理的原因。

### 参考文档：

1. [监控 SQL Server 的运行状况--常用检测语句](https://blog.csdn.net/isoleo/article/details/39960575)
2. [查看执行计划](https://www.cnblogs.com/mcgrady/p/4174185.html)
3. [SqlServer 索引](https://www.cnblogs.com/yunfeifei/p/4140385.html)
4. [SqlServer 基础进阶](https://www.cnblogs.com/CreateMyself/p/6117352.html)
5. [官方文档](https://docs.microsoft.com/en-us/sql/sql-server/sql-server-technical-documentation?toc=..%2Ftoc%2Ftoc.json&view=sql-server-2017)