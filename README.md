# ChatGPT-Next-Web平台，一键安装脚本

## 准备工作
* 申请好OpenAI的 API KEY
* 准备一台国外的虚拟机(系统Ubuntu 18.04+/Centos 7+/Debian 9+/),AWS免费使用一年，方法请自行搜索。
* 准备一个域名，并做好解析，也可以直接用IP地址访问。
* 安装好 wget

## 安装 wget
### Ubuntu/Debian 系统

```
apt update
apt install -y wget
```

### Centos/Oracle 系统

```
yum install -y wget
```

## 安装/更新ChatGPT-Next-Web平台

```
wget -N --no-check-certificate -q -O chatgpt-web-onkey-install.sh "https://raw.githubusercontent.com/dengyue1985/ChatGPT-Web-OneKey/main/chatgpt-web-onkey-install.sh" && chmod +x chatgpt-web-onkey-install.sh && bash chatgpt-web-onkey-install.sh
```

## 注意事项

* 如果你不了解脚本中各项设置的具体含义，除域名外，请使用脚本提供的默认值
* 使用本脚本需要你拥有 Linux 基础及使用经验，了解计算机网络部分知识，计算机基础操作
* 目前支持Ubuntu 18.04+ / Centos7+ /Debian 9+ /Oracle Linux
* https证书的有效期为3个月，到期后会自动续签，每日凌晨会检查证书有效期。
* 脚本使用80和443端口，请在云平台的安全组中放行这两个端口
* 如果与其他程序共用一台服务器的情况下，请注意修改端口
* 本 bash 中的各项服务，均采用docker容器进行安装部署

## ！！特别注意！！
> https证书生成必须通过80端口验证，如果有其他程序占用，先关闭此程序，脚本安装完成后再重新开启即可

## 自有证书
> 如果你已经拥有了你所使用域名的证书文件，可以脚本执行完成后，将 crt 和 key 文件命名为 nginx_ssl.crt nginx_ssl.key 放在 /root/certs 目录下请注意证书文件权限及证书有效期，自定义证书有效期过期后请自行续签
> 执行脚本选择13.重启 web服务

## 海外虚拟机推荐
自用VPS推荐
### raksmart 有很多活动，最低0.99刀/月
https://billing.raksmart.com/whmcs/aff.php?aff=6162

### RackNerd
1G / 1C / 17G SSD / 3T   $10.98/年
https://my.racknerd.com/aff.php?aff=8533&pid=358
[更多](https://github.com/dengyue1985/ChatGPT-Web-OneKey/blob/main/README_RN_VPS.md)

### AWS 
新用户免费使用一年，需要信用卡验证
 
