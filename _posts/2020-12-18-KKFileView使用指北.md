# KKFileView使用指北



### 需求

1. 比较好的word,ppt,xlsx的预览效果
2. 内网可用，可以独立部署
3. 可作为公共解决方案



### 和其他解决方案对比

所有的解决方案实质上都是调用某office的服务来实现的，根据采用的office类型可以大致分为两类

1. [在windows服务器使用msoffice进行转换](https://www.cnblogs.com/yanweidie/p/4516164.html)
2. 使用libreoffice或openoffice在linux服务器上进行转换

jobconverter和unoconv都支持以上所有的服务调用。

|                                                             | 语言   | 转换器                                                      | 效果                             | 使用方式         |
| ----------------------------------------------------------- | ------ | :---------------------------------------------------------- | -------------------------------- | ---------------- |
| [KKFileView](https://kkfileview.keking.cn/zh-cn/index.html) | java   | [JODConverter](https://github.com/sbraconnier/jodconverter) | 较好(不可调节)                   | 直接生成预览url  |
| [gotenberg](https://github.com/thecodingmachine/gotenberg)  | go     | unoconv                                                     | 一般,excel预览存在问题(不可调节) | 提供api供调用    |
| [unoconv](https://github.com/unoconv/unoconv)               | python |                                                             | 可调节                           | 提供命令行供调用 |



### 存在问题

1. 无权限控制，复制url给任何人都可以打开预览
2. url参数是用户可控的，通过修改此参数，可触发SSRF漏洞。虽然可以指定trust.host来限制url，但也会暴露下载地址
3. 预览失败页面有反馈群[doge]



### 修改

  KKFileView是基于Spring的项目，可以添加Filter来处理。[修改后的代码地址](https://github.com/run-dream/kkFileView)

1. 增加auth控制

   ```properties
   # 是否启用权限校验
   auth.enabled =  ${KK_AUTH_ENABLED:true}
   # 授权验证的回调地址
   auth.url =  ${KK_AUTH_URL:http://127.0.0.1:7001/auth}
   # 回调验证的json的路径
   auth.success-path = ${KK_AUTH_SUCCESS_PATH:success}
   ```

   下载文件前,会将用户的url转发给授权服务来进行判断，无权限则提供预览服务

2. 增加download-prefix处理

   ```properties
   # 支持下载资源url不指定完整路径
   base.download-prefix = ${KK_DOWNLOAD_PREFIX:http://127.0.0.1:7001}
   ```

   下载时会读取prefix和用户输入的部分拼接 从而实现隐藏实际下载路径的目的



### 部署

1. 打包

   ```bash
   mvn clean package -DskipTests -Prelease
   ```

2. 生成镜像

   ```bash
   docker build -t keking/kkfileview .
   ```

3. 发布镜像到私有仓库

   ```bash
   docker login your_repo
   docker tag keking/kkfileview your_repo/kkfileview:1.0
   docker push your_repo/kkfileview:1.0
   ```

4. 文件服务实现下载和权限控制接口,并提供预览链接给前端

5. 修改 docker-compose

   ```yaml
   kkfileview:
   	restart: always
   	image: your_repo/kkfileview:1.0
   	containner_name: kkfileview
   	volumes:
   	  - ./kkfileview:/opt/kkFileView-2.2.1/config
   ```

   你可以通过修改自己目录的application.properties来控制容器启动时的配置

6. 修改nginx转发

   -  修改 application.properties 

     ```properties
     base.url = ${KK_BASE_URL:your_domain}
     ```

   - 修改 nginx配置，增加转发

     ```conf
     location /preview/ {
         proxy_pass http://127.0.0.1:8012;
     }
     ```


### Tips

1. url参数 

   由于下载地址时一个接口,kkfileview无法从地址获取到文件名,所以需要显示声明fullfilename=xxx。此外由于增加了权限控制，所以url中还包括了用来校验的token数据。这些构成完整的url后，还需使用encodeURIComponent进行处理。

2. docker换源，以及发布

   docker本身的源太慢了，可以修改

   ```json
    "registry-mirrors": [
       "https://docker.mirrors.ustc.edu.cn"
     ],
   ```

   此外发布时，最好带上版本信息，以免都使用latest导致如果有更新，使用方无法获取到。其实`latest`就是个普通标签，不要期望它是最新或最稳定的版本。它只是个名字，没有其它附加作用，更不会自动更新。



