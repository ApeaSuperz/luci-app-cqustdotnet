<h1 align="center">
<img src="img/logo.jpg" alt="logo" width="200" />
<br/>CQUST.net<br/>
</h1>

<p align="center">让 OpenWrt 连接认证重科校园网的工具</p>

## 这是什么？

CQUST.net 是一个用于连接认证重科校园网的工具，它可以在装有 OpenWrt 并且满足[依赖](#依赖)的设备上运行。

CQUST.net 可以检测校园网的认证情况，自动进行认证。

## 依赖

* luci
* luci-base
* bash

绝大多数安装了 OpenWrt 的设备都满足以上依赖。

## 使用

### 准备

将符合条件的 OpenWrt 设备接入校园网。

### 安装

目前，本软件没有上传到软件源仓库的计划，请自行[下载](https://github.com/ApeaSuperz/luci-app-cqustdotnet/releases)到装有 OpenWrt 的设备中，再使用 opkg 从本地安装。

使用 opkg 安装：

```sh
opkg install 'path-to-luci-app-cqustdotnet.ipk'
```

例如 .ipk 文件的路径为 /tmp/upload/luci-app-cqustdotnet.ipk，则使用以下命令安装：

```sh
opkg install '/tmp/upload/luci-app-cqustdotnet.ipk'
```

### 配置

1. 在 LuCI 的 `服务` 中找到 `CQUST.net`，在 `账号` 栏中添加校园网的账号。
2. 在 `主页` 栏中，可以选择性更改网络连通性检测的时间间隔。对于性能较差的设备，不建议将间隔设置得太短。
3. 在 `主页` 栏勾选 `总开关` 后，点击 `保存&应用设置`，CQUST.net 就会在后台运行了。

### 查看运行状况

您可以在 `CQUST.net` 的 `日志` 栏中查看运行状况。
