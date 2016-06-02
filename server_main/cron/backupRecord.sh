#!/bin/sh

nowday=`date +%Y%m%d`
host=192.168.0.138
user=root
pass=apple_skynet_mysql
mysql -h$host -u$user -p$pass QPRecordDB -e"create table DrawInfo_new like DrawInfo;rename table DrawInfo to DrawInfo_$nowday,DrawInfo_new to DrawInfo;create table DrawScore_new like DrawScore;rename table DrawScore to DrawScore_$nowday,DrawScore_new to DrawScore;create table UserInOut_new like UserInOut;rename table UserInOut to UserInOut_$nowday,UserInOut_new to UserInOut;";
