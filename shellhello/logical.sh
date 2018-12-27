#!/bin/bash

# if [   -n "abc" ] && [ -n "aa" ]     #   [ "${myvar}" \< "abc" ] && [ "${myvar}" \> "abc" ]
# if test  -n "abc" && test -n "aa"    # [ $f1 -nt $f2 ] || [ $f1 -ot $f2 ]  ##newer than, older than
# if [[ -n "abc" ]] && [[ -n "aa" ]]
# if [[    -n "abc" && -n "aa" ]]
##
##For ..
#for i in {1..3}          ## 1 2 3
# for i in `seq 3`       ## 1 2 3 
# for i in `seq 1 3`     ## 1 2 3
# for i in `seq 1 2 10`  ## 1 3 5 7 ..
for ((i = 1; i < 10; i++))   ## 1 2 3 4 .. 
do
  echo i=$i
done

## while: exit when not 0,  until: exit when 0
i=0
until [[ $i -eq 1 ]]  
do
  echo "test until"
  let i=$i+1
done