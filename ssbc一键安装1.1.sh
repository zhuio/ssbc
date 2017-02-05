#!/bin/bash
#我本戏子 2015.12
#环境检测
 python -V          
 systemctl stop firewalld.service  
 systemctl disable firewalld.service   
 systemctl stop iptables.service  
 systemctl disable iptables.service   
#获取ssbc安装包并解压
 wget https://github.com/78/ssbc/archive/master.zip
 yum -y install unzip
 unzip master.zip
#解压后 源码在/root/ssbc-master目录
#安装数据库及所需环境
 yum -y install gcc
 yum -y install gcc-c++
 yum -y install python-devel
 yum -y install mariadb
 yum -y install mariadb-devel
 yum -y install mariadb-server
 cd ssbc-master
 wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py 
 python get-pip.py
 pip install -r requirements.txt
 pip install  pygeoip
#创建ssbc数据库并修改my.cnf配置
 systemctl start  mariadb.service 
 mysql -uroot  -e"create database ssbc default character set utf8;"  
 sed -i '/!includedir/a\wait_timeout=2880000\ninteractive_timeout = 2880000\nmax_allowed_packet = 512M' /etc/my.cnf
#建立文件夹
 mkdir  -p  /data/bt/index/db /data/bt/index/binlog  /tem/downloads
 chmod  755 -R /data
 chmod  755 -R /tem
#安装Sphinx
 yum -y install unixODBC unixODBC-devel postgresql-libs
 wget http://sphinxsearch.com/files/sphinx-2.2.9-1.rhel7.x86_64.rpm
 rpm -ivh sphinx-2.2.9-1.rhel7.x86_64.rpm
 systemctl restart mariadb.service  
 systemctl enable mariadb.service 
#启动searchd守护进程
 searchd --config ./sphinx.conf
#Django建表
 python manage.py makemigrations
 python manage.py migrate
#生成索引
 indexer -c sphinx.conf --all 
 ps aux|grep searchd|awk '{print $2}'|xargs kill -9
 searchd --config ./sphinx.conf
#启动网站并在后台运行
 nohup python manage.py runserver 0.0.0.0:80 >/dev/zero 2>&1&          
while true; do
    read -p "确定浏览器能打开网站？[y/n]" yn
    case $yn in
        [Yy]* ) cd workers; break;;
        [Nn]* ) exit;;
        * ) echo "请输入yes 或 no";;
    esac
done
#运行爬虫并在后台运行
nohup python simdht_worker.py >/dev/zero 2>&1&
#定时索引并在后台运行
nohup python index_worker.py >/dev/zero 2>&1&  
#增加后台管理员
 cd ..
 python manage.py createsuperuser
#开机自启动
 chmod +x /etc/rc.d/rc.local
 echo "systemctl start  mariadb.service " >> /etc/rc.d/rc.local
 echo "cd /root/ssbc-master " >> /etc/rc.d/rc.local
 echo "indexer -c sphinx.conf --all " >> /etc/rc.d/rc.local
 echo "searchd --config ./sphinx.conf " >> /etc/rc.d/rc.local
 echo "nohup python manage.py runserver 0.0.0.0:80 >/dev/zero 2>&1& " >> /etc/rc.d/rc.local
 echo "cd workers " >> /etc/rc.d/rc.local
 echo "nohup python simdht_worker.py >/dev/zero 2>&1& " >> /etc/rc.d/rc.local
 echo "nohup python index_worker.py >/dev/zero 2>&1& " >> /etc/rc.d/rc.local