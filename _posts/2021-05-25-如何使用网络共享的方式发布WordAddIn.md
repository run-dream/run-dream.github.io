---
layout: post
date: 2021-05-25 19:00
category: Word
tags:
  - Office
  - Windows
---



### 生成DEMO

1. 安装VSStudio 选中 Offce/Share Point开发

2. 新建项目 选择类型 Word Web 外接程序

3. 为测试请求服务端接口是否可行，修改 Home.js

   ```js
   const xhr = new XMLHttpRequest();
   xhr.open('get', '/api/external/test', false);
   xhr.send();
   
   body.insertText(xhr.responseText, Word.InsertLocation.end);
   ```



### 发布DEMO

1. 打开 Manifest 文件
2. 点击VSStudio上的生成 -> 发布
3. 部署Web项目 选择部署到文件夹
4. 打包外接程序 地址填web服务地址 会生成一个OfficeAppManifest文件夹 
5. 将第4步得到的文件夹 复制到生成Web项目的文件夹下



### 部署web站点

我这里使用nginx 代理来处理整合web资源

```conf
server {
    listen 9999；
    // 省略不重要的部分
    
    location / {
        root ${发布的Web项目的目录};
    }
    
    location ^~ /api/ {
        proxy_pass ${后端服务的地址}
    }
}
```



### 共享文件夹

比较坑爹的地方是Win10默认关闭了共享文件夹的功能，需要按照下面的方式开启

1. 小娜搜索 services 查看以下服务是否开启
   - Computer Browser; 
   - DHCP Client; DNS Client; 
   - Function Discovery Provider Host;
   - Function Discovery Resource Publication;
   - Network Connections; 
   - Network Location Awareness;
   - Remote Procedure Call (RPC); 
   - Server; 
   - SSDP Discovery; 
   - TCP/IP Netbios helper; 
   - UPnP Device Host; 
   - Workstation. 

   将未开启的服务改为自动启动

2.  然后发现缺少 Computer Browser 服务，小娜搜索 windows 功能 ，在选项里启用 
   - SMB 1.0/CIFF 文件共享支持
3. 重启电脑



然后将发布的文件夹设置为贡献文件夹，记录下生成的网络路径



### 使用注册表脚本配置信任

1. 在文本编辑器中，创建名为 TrustNetworkShareCatalog.reg 的文件。

2. 在文件中添加以下内容：

   ```bash
   Windows Registry Editor Version 5.00
   
   [HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\WEF\TrustedCatalogs\{-random-GUID-here-}]
   "Id"="{-random-GUID-here-}"
   "Url"="\\\\-share-\\-folder-"
   "Flags"=dword:00000001
   ```

3. 在众多在线 GUID 生成工具中选用一个（例如 [GUID 生成器](https://guidgenerator.com/)）来生成一个随机 GUID，并在 TrustNetworkShareCatalog.reg 文件中，将 *两个位置* 的“-random-GUID-here-”字符串都替换为 GUID。 （应保留右侧 `{}` 符号）。

4. 将 `Url` 值替换为你之前[共享](https://docs.microsoft.com/zh-cn/office/dev/add-ins/testing/create-a-network-shared-folder-catalog-for-task-pane-and-content-add-ins#share-a-folder)的文件夹的完整网络路径。 （请注意，URL 中的所有 `\` 字符都必须成双出现。）

5. 关闭所有Office应用

6. 运行 TrustNetworkShareCatalog.reg



### 在Office中加载WebAddIn

1. 打开文档
2. 激活编辑状态
3. 插入 -> 我的加载项 即可使用发布的插件

### 参考文档

1. [生命周期](https://docs.microsoft.com/zh-cn/office/dev/add-ins/overview/office-add-ins)
2. [发布](https://docs.microsoft.com/zh-cn/office/dev/add-ins/testing/create-a-network-shared-folder-catalog-for-task-pane-and-content-add-ins)
3. [win10网络共享](https://www.bgyjr.com/key/%E5%90%AF%E7%94%A8%E6%96%87%E4%BB%B6%E5%92%8C%E6%89%93%E5%8D%B0%E6%9C%BA%E5%85%B1%E4%BA%AB%20%E6%97%A0%E6%B3%95%E4%BF%9D%E5%AD%98%E4%BF%AE%E6%94%B9.html)