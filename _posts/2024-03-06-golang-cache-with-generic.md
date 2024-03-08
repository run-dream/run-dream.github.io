---
layout: post
date:       2024-03-08 15:00:00
category: golang
title: 如何用 golang 里实现一个通用的缓存，关于泛型和反射
tags:
    - golang
---

## 背景

在编写业务代码的时候，经常会有使用redis对热点数据进行缓存的需求，这里的逻辑可以抽象为：

1.  为不同的查询条件生成不同的缓存key (getKey)
2.  从 redis 里读取对应key的内容 (getFromCache) 如果能获取到则直接返回
3.  如果redis里不存在对应的内容，则改从数据源里获取 fetchDataSource&#x20;
4.  将数据源里获取到的内容写回redis 并设置过期实际

其中很多步骤是通用的，我们可以**抽象成工具类**。

我们之前使用 typescript 的时候，是这样实现的

```typescript

export abstract class GenericCache<T, F> {
    /**
     * @description 抽象方法, 实现缓存过期时间规则，单位秒
     * @param params 
     * @param content 
     */
    abstract getExpireTime(params: T, content?: F);

    /**
     * @description 抽象方法, 缓存的key生成规则 
     * @param params 
     * @returns 
     */
    abstract getKey(params: Partial<T>): string;

    /**
     * @description 抽象方法, 当缓存里不存在这个数据时, 获取源数据
     * @param params 
     * @returns 
     */
    abstract fetchDataSource(params: T): Promise<F>;
    /**
     * @description 从缓存中获取数据，如果没有则刷新
     * @param params 
     * @returns 
     */
    public async get(params: T): Promise<F> {
        const str = await getRedis().get(this.getKey(params));
        if (isNullOrUndefined(str)) {
            const result = await this.refresh(params);
            return result;
        } else {
            let result: F;
            try {
                result = JSON.parse(str);
            } catch (err) {
                return this.refresh(params,);
            }
            return result;
        }
    }

    /**
     * 从缓存中获取数据，不刷新
     * @param params 
     * @returns 
     */
    protected async getWithoutRefresh(params: Partial<T>) {
        const str = await getRedis().get(this.getKey(params));
        if (isNullOrUndefined(str)) {
            return null;
        }
        const result = getJsonInfo<F>(str, {} as unknown as F);
        return result;
    }

    /**
     * @description 刷新缓存
     * @param params 
     * @returns 
     */
    async refresh(params: T): Promise<F> {
        const content = await this.fetchDataSource(params,);
        await this.writeToCache(params, content,);
        return content;
    }

    /**
     * @description 写入缓存
     * @param params 
     * @param content 
     * @returns 
     */
    async writeToCache(params: T, content: F) {
        const str = JSON.stringify(content);
        const expire = this.getExpireTime(params, content);
        if (expire <= 0) {
            return;
        }
        await getRedis().set(this.getKey(params,), str);
        if (expire !== null) {
            await getRedis().expire(this.getKey(params,), expire);
        }
    }

    /**
     * @description 删除缓存
     * @param params 
     */
    async del(params: T) {
        await getRedis().del(this.getKey(params,));
    }

    /**
     * @description 设置缓存
     * @param params 
     * @param content 
     */
    async set(params: T, content: F) {
        await this.writeToCache(params, content,);
    }
} 
```

使用时，只需要继承这个类，并实现 abstract 的三个方法方法,就可以满足对不同类型数据的缓存

```typescript
class RoleInfoCacheClass extends GenericCache<number, RoleInfoRecord>{
    getKey(roleId: number): string {
        return `RoleInfo:${roleId}`;
    }

    async fetchDataSource(roleId: number): Promise<RoleInfoRecord> {
        const role = await RoleInfoModel.findOne({
            RoleId: roleId,
        });
        return role;
    }

    getExpireTime() {
        return ONE_MIN_SECONDS * 3;
    }
}

export const RoleInfoCache = new RoleInfoCacheClass();
```

当转型到golang的时候，我们自然也会想把这个方法迁移过去。

## 问题

### 组合替代泛型

**golang 中并不存在 「类」的概念，所以严格意义上说在 Go 中是没有「继承」一说的，所以我们必须通过 “组合” 的方式来实现 OOP 中 “继承” 所需的特性**。

听起来有点抽象，举个例子理解一下，用面向对象的思想来描述一下狗和动物的关系

```typescript
class Animal {
  name: string;
  constructor(name: string){
    this.name = name;   
  }
}

class Dog extends Animal {};
```

如果用组合来实现, 如果我们直接翻译

```typescript
type Animal struct {
  name string
}

type Dog struct {
  Animal
}
```

它们用起来确实很类似，都可以通过“子类”直接访问“父类”的属性 `Dog.name` 。但这两个有本质差别：

对于 typescript，`name` 确实是 `Dog` 的属性，不可以 `Dog.Animal.name` 这样来访问。可对于 golang，`Dog` 是没有 `name` 属性的。**`Dog.name` 只是一个 `Dog.Animal.name` 的语法糖。** 实际上 `Dog` 中有一个类型为 `Animal` 的变量（默认变量名与类型一致），`name` 依然只属于 `Animal`

但是这个实现看起来有点不太符合我们的直觉，狗的身体里有一个动物，像是什么人体炼成的恐怖故事。

更重要的是，仔细想想，这个实现其实根本无法工作。如果我们现在要实现一个喂养动物的方法, typescript 这样是可以运行的

```typescript
function feed(a: Animal){
  console.log(a.name + '吃饱了')
}

feed(new Dog('妮娜'));
```

·而用在golang里,则会编译不通过

```go
func feed(a Animal){
  fmt.Println(a.name + "吃饱了")
}

feed(Dog{Animal{"妮娜"}) // cannot use dog(variable of type Dog) as Animal value in argument to feed
```

因为typescript有继承，`Dog` 也是一个 `Animal`，因此这么传参毫无问题。不过在 Go 中，对象只能有一个类型——是 `Dog` 了就不能是 `Animal`。`Dog` 的确包含 `Animal` 但它还是 dog。就好像，汽车包含轮子，它还叫汽车，不能管它叫轮子。

那怎么办呢？也许会有人说，那我可以

```go
feed(Dog{Animal{"妮娜"}.Animal)
```

~~又不是不能跑~~。但这好吗？这不好。Dog本身的额外信息丢失了。

那我们推倒重来，golang里的类型的设计理念是 duck type，也就是

> “当看到一只鸟走起来像鸭子、游泳起来像鸭子、叫起来也像鸭子，那么这只鸟就可以被称为鸭子。

在鸭子类型中，我们重点关注对象能做什么，而不必在意它是谁。

**由此可见，Go 的设计与传统面向对象完全不同。我们也不能把之前的 OOP 思路强行套在 Go 的开发中。更不应该去找什么「等价写法」。**

**Go 是组合而非继承**，因此在建模过程中我们得 **摒弃层级观念，把线性结构转为换网状结构。 **

于是我们引入了 interface 来实现

```go
type Animal interface  {
	Name() string
}
  
type Dog struct {
	name string
}
  
func (d *Dog) Name() string {
	return d.name
}

func feed(a Animal) {
    println(a.Name() + "吃饱了")
}

dog := &Dog{"妮娜"}
feed(dog)
```

### &#x20;golang 泛型

现在我们已经切换到了使用组合来实现的思路上来了。回到我们最开始的问题，为了一开始的实现里我们应用了泛型来解决类型的困扰。

> 泛型程序设计（generic programming）是程序设计语言的一种风格或范式。泛型允许程序员在强类型程序设计语言中编写代码时使用一些以后才指定的类型，在实例化时作为参数指明这些类型。 – 百度百科

好消息是 golang泛型终于伴随着Go1.18发布了。和 typescript 的类型体操一样，引入了比较多的概念，我们简单梳理一下

*   *类型参数* 泛型函数或类型的一个占位符，表示一个未知的类型。

    &#x20;类型参数用方括号\[]括起来，放在函数名或类型名之后。

    ```go
    // [T any] 是类型参数
    func MyFunc[T any](a T) {} 
    ```
*   *约束* 限制类型参数的方式，用于指定类型参数必须满足的条件。约束可以是接口类型或其他具有类型参数的类型。

    ```go
    // [T int | float32 | float64] 中 int | float32 | float64 是对 T的约束, T 可以是其中任意一种类型
    func Add[T int | float32 | float64](a, b T) T {
        return a + b
    }
    ```

    *近似约束元素*   如基础类型为int32的类型

    ```go
    // ~int32 是近似约束元素
    type StatusCode int32
    type HttpCode int32

    func IsValid[T ~int32](code T) bool {
        return code > 0
    }
    ```

    *预定义约束*  用于表示常见的类型集合 any约束表示任何类型，comparable约束表示可比较的类型（支持==和!=操作符）
*   *泛型函数*  使用类型参数的函数，可以处理不同类型的参数。泛型函数的定义和普通函数类似，只是在函数名后面添加了类型参数列表

    ```go
    // 下面整个就是泛型函数
    func MyFunc[T any](a T) {} 
    ```
*   *泛型类型* 使用类型参数的类型，可以表示不同类型的数据结构。泛型类型的定义和普通类型类似，只是在类型名后面添加了类型参数列表。

    ```go
    type MySlice[T any] 
    ```
*   *类型推断 *在许多情况下，可以使用类型推断来避免必须显式写出部分或全部类型参数，这个是时候可以

```go
func Print[T any](s T) {
    fmt.Println(s)
}

s := []int{1, 2, 3}

// 显示指定参数类型
Print[[]int](s)
// 推断参数类型,
Print(s)
```

注意事项：

1.  目前匿名函数不能自己定义类型，但是匿名函数可以使用别处定义好的类型实参

    ```go
    // 错误，匿名函数不能自己定义类型实参 method must have not type parameters
    fn := func[T int | float32](a, b T) T {
        return a + b
    } 

    fmt.Println(fn(1, 2))

    func MyFunc[T int | float32 | float64](a, b T) {
        // 匿名函数可使用已经定义好的类型形参
        fn2 := func(i T, j T) T {
            return i%j
        }
        fn2(a, b)
    }
    ```
2.  目前 Go的方法并不支持泛型，但是， 我们可以通过定义泛型类型来实现

    ```go
    type Person struct{}

    // 不支持泛型方法 syntax error: non-declation statement outside function body (compile)
    func (p *Person) Say[T int | string](s T) {
        fmt.Println(s)
    }

    // 但可以通过定义泛型类型来实现
    type Person[T int | string] struct{}

    func (p *Person[T]) Say(s T) {
        fmt.Println(s)
    }
    ```

## &#x20;实现

综合前面的内容，我们考虑将原GenericCache中的抽象方法声明为 Cacheable interface，另外实现一个 RedisCache 的结构体，在这里处理好通用的方法，之后要使用的时候只需要实现自己独立的逻辑，然后作为组合的一部分传入。

```go
// 声明
type Cacheable[T any, F any] interface {
	GetKey(params T) string
	GetWithoutRefresh(params T) (F, error)
	GetExpire(result F) time.Duration
}

type RedisCache[T any, F any] struct {
	ctx context.Context
	rds redis.UniversalClient
	Cacheable[T, F]
}

// 实现
func (r *RedisCache[T, F]) Get(params T) (value F, err error) {
	key := r.GetKey(params)
	result, err := r.rds.Get(r.ctx, key).Result()
	if err == redis.Nil {
		value, err = r.Refresh(params)
		if err != nil {
			return value, err
		}
		return value, nil
	}
	if err != nil {
		return value, err
	}
	err = json.Unmarshal([]byte(result), &value)
	if err != nil {
		return value, err
	}
	return value, err
}

func (r *RedisCache[T, F]) Set(params T, value F) (err error) {
	key := r.GetKey(params)
	expire := r.GetExpire(value)
	bytes, err := json.Marshal(value)
	if err != nil {
		return err
	}
	err = r.rds.Set(r.ctx, key, bytes, expire).Err()
	if err != nil {
		return err
	}
	return nil
}

func (r *RedisCache[T, F]) Refresh(params T) (F, error) {
	value, err := r.GetWithoutRefresh(params)
	if err != nil {
		return value, err
	}
	err = r.Set(params, value)
	return value, err
}

func (r *RedisCache[T, F]) Del(params T) error {
	key := r.GetKey(params)
	err := r.rds.Del(r.ctx, key).Err()
	if err != nil {
		return err
	}
	return nil
}

func NewRedisCache[T any, F any](ctx context.Context, rds redis.UniversalClient, imp Cacheable[T, F]) *RedisCache[T, F] {
	return &RedisCache[T, F]{rds: rds, ctx: ctx, Cacheable: imp}
}

// 使用示例
type ActivityCache struct {
	ctx context.Context
	db  dataease.IDB
}

func (c *ActivityCache) GetKey(id uint32) string {
	return redisease.K("Activity:" + strconv.Itoa(int(id)))
}

func (c *ActivityCache) GetExpire(activity *activity.Activity) time.Duration {
	return time.Hour * 24 
}

func (c *ActivityCache) GetWithoutRefresh(id uint32) (*activity.Activity, error) {
	activityModel := activity.New(c.db)
	activity, err := activityModel.Get(c.ctx, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &activity, nil
}

func NewActivityCache(ctx context.Context, rds redis.UniversalClient, db dataease.IDB) *common.RedisCache[uint32, *activity.Activity] {
	return NewRedisCache(ctx, rds, &ActivityCache{db: db, ctx: ctx})
}

// 使用
activityCache := activityService.NewActivityCache(ctx, rds, db)
activity, err := activityCache.Get(activityId)
```



## &#x20;扩展

那么在Go1.18之前，没有泛型的时候，我们要怎么做到类似的效果

```go

type Cacheable interface {
	GetKey(params interface{}) string
	GetWithoutRefresh(params interface{}) (interface{}, error)
	GetExpire(result interface{}) time.Duration
}


type RedisCache struct {
	ctx context.Context
	rds redis.UniversalClient
	Cacheable
}

// 为了处理基础类型的数据，需要将 result 作为参数传入
func (r *RedisCache) Get(params interface{}, result interface{}) (err error) {
	key := r.GetKey(params)
	result, err = r.rds.Get(r.ctx, key).Result()
	return
}

func (r *RedisCache) Set(params interface{}, value interface{}) (err error) {
	key := r.GetKey(params)
	expire := r.GetExpire(value)
	bytes, err := json.Marshal(value)
	if err != nil {
		return err
	}
	err = r.rds.Set(r.ctx, key, bytes, expire).Err()
	if err != nil {
		return err
	}
	return nil
}

func (r *RedisCache) Refresh(params interface{}) (interface{}, error) {
	value, err := r.GetWithoutRefresh(params)
	if err != nil {
		return value, err
	}
	err = r.Set(params, value)
	return value, err
}

func (r *RedisCache) Del(params interface{}) error {
	key := r.GetKey(params)
	err := r.rds.Del(r.ctx, key).Err()
	if err != nil {
		return err
	}
	return nil
}


func NewRedisCache(ctx context.Context, rds redis.UniversalClient, imp Cacheable) *RedisCache {
	return &RedisCache{rds: rds, ctx: ctx, Cacheable: imp}
}

type ActivityCache struct {
	ctx context.Context
	db  dataease.IDB
}

func (c *ActivityCache) GetKey(id interface{}) string {
	return redisease.K("Activity:" + strconv.Itoa(int(id.(uint32))))
}

func (c *ActivityCache) GetExpire(activity interface{}) time.Duration {
	return time.Hour * 24 
}

func (c *ActivityCache) GetWithoutRefresh(id interface{}) (interface{}, error) {
	activityModel := activity.New(c.db)
	activity, err := activityModel.Get(c.ctx, id.(uint32))
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &activity, nil
}

func NewActivityCache(ctx context.Context, rds redis.UniversalClient, db dataease.IDB) *RedisCache {
	return NewRedisCache(ctx, rds, &ActivityCache{db: db, ctx: ctx})
}

activityCache := NewActivityCache(ctx, rds, db)
var activity *activity.Activity
err := activityCache.Get(1, activity)
```

从写法上来看，interfaces{} 类型和无处不在，无法对类型进行约束，尤其存在大量的类型断言，如果失败的话，可能会导致程序 panic。

上面的 Get 方法的处理方式，很容易让我们想到 json.Unmarshall，这里也是存在不确定的类型，那么这里是怎么实现的呢，我们点开代码研究

```go
func (d *decodeState) unmarshal(v any) error {
	rv := reflect.ValueOf(v)
	if rv.Kind() != reflect.Pointer || rv.IsNil() {
		return &InvalidUnmarshalError{reflect.TypeOf(v)}
	}

	d.scan.reset()
	d.scanWhile(scanSkipSpace)
	// We decode rv not rv.Elem because the Unmarshaler interface
	// test must be applied at the top level of the value.
	err := d.value(rv)
	if err != nil {
		return d.addErrorContext(err)
	}
	return d.savedError
}
```

很明显可以看到这里是通过反射来动态获取类型的。这里不继续往细节讲了。简单学习下golang的反射

goto: <https://www.cnblogs.com/jiujuan/p/17142703.html>

Go 中的反射是建立在类型系统之上，它与空接口 interface{} 密切相关。

每个 interface{} 类型的变量包含一对值 （type，value），type 表示变量的类型信息，value 表示变量的值信息。

> `reflect.TypeOf()` 获取类型信息，返回 [Type](https://cs.opensource.google/go/go/+/refs/tags/go1.18.8\:src/reflect/type.go;l=39) 类型；
>
> `reflect.ValueOf()` 获取数据信息，返回 [Value](https://cs.opensource.google/go/go/+/refs/tags/go1.18.8\:src/reflect/value.go;l=39) 类型。

反射和泛型的区别：

Golang 的反射是指在运行时动态地获取和操作程序的内部结构。它允许程序在不知道值的类型的情况下进行操作，并且可以在不修改代码的情况下对其进行修改。

而泛型其实是在编译阶段处理的，所以性能更好。

## 参考文档

<https://chenhe.me/post/inheritance-in-go/>

<https://www.kunkkawu.com/archives/shen-ru-li-jie-golang-de-fan-xing>

<https://www.cnblogs.com/jiujuan/p/17142703.html>

<https://www.cnblogs.com/kevinwan/p/16223984.html>
