#!/bin/bash

url="https://quixy.swinfra.net/quixy/query/detail.php?ISSUEID=QCCR8B30377"
echo "url=${url}"

#### Replacement
## ${string/old/new}  string中第一个old替换为new
echo ${url/https/http}
## ${string//old/new}   string中所有old替换为new
echo ${url/h/XX}
#### Truncate
# ${string::m}    string从下标0开始长度为m的子串
# ${string:n}     string从下标n到结尾的子串   . Start with 0.
# ${string:n:m}   string从下标n开始长度为m的子串

#### Delete on condition some string matched
# ${string#pattern}   string从左到右删除pattern的最小通配
# ${string##pattern}  string从左到右删除pattern的最大通配
# ${string%pattern}   string从右到左删除pattern的最小通配
# ${string%%pattern}  string从右到左删除pattern的最大通配
#    获取文件名：${path##*/} (相当于basename命令的功能)
#    获取目录名：${path%/*} (相当于dirname命令的功能)
#    获取后缀名：${path##*.}
echo ${url#htt}
echo ${url#*quixy}

