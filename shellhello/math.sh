#!/bin/bash

echo $(( 1+1 ))        # 最简单的1+1
echo $(( (1+2)*3/4 ))  # 表达式中还可以带括号
echo $(( 1<<32 ))      # 左移右移也支持，但仅限于-4294967296~4294967296之间的数值
echo $(( 1&3 ))        # &、^、|、~ 这样的位操作亦支持
echo $(( i=1+2 ))       # 将1+2计算出结果后赋值给i，后续若`echo ${i}`会得到3
echo $(( i++ ))              # 变量i自增1
echo $(( i+=3 ))             # 变量i自增3

### expr
i1=2
i2=3
echo "'expr 2 + 3=' `expr $i1 + $i2`"   # 5
echo "'expr 2 - 3=' `expr $i1 - $i2`"   # -1
echo "'expr 2 \* 3=' `expr $i1 \* $i2`" # 6
echo "'expr 2 \/ 3=' `expr $i1 / $i2`"  # 0
echo "'expr 2 \& 3=' `expr $i1 \& $i2`" # 2  ARG1 if neither argument is null or 0, otherwise 0
echo "'expr 2 \| 3=' `expr $i1 \| $i2`" # 2  ARG1 if it is neither null nor 0, otherwise ARG2
echo "'expr 2 \= 3=' `expr $i1 \= $i2`" # 0  ARG1 is equal to ARG2

str1='hello1'
str2='hello2'
echo "'expr substr hello1 1 3'=`expr substr $str1 1 3`" # hel
echo "'expr index  hello1 hel'=`expr index  $str1 hel`" # 1
echo "'expr length hello1    '=`expr length $str1`"     # 6


# let arg1 [arg2 ......]k
# [ ]表示可以有多个参数，arg n (n=1,2…)
# 运算符与操作数据之间不必用空格分开，但表达式与表达式之间必须要用空格分开
# 当运算符中有<、>、&、|等符号时，同样需要用引号（单引号、双引号）或者斜杠来修饰运算符
i1=10
let i3=$i1+3 && echo "i3=$i3"
let i3=$i1-3 && echo "i3=$i3"
let i3=$i1*3 && echo "i3=$i3"
let i3=$i1/3 && echo "i3=$i3"
let i3=($i1+2)*3 && echo "i3=$i3"

echo $str1 | awk '{ print toupper($0) }' ## echo $str1 | tr [a-z] [A-Z]
echo $str1 | awk '{ print tolower($0) }'
  
##awk
echo ad|awk '{ split( "20:18:00", time, ":" ); print time[1] }'  ## print 20