#!/bin/bash
echo $i

######### Test Map
#declare -A map=(["sunjun"]="sunjun_a" ["jason"]="sunjun_b" ["lee"]="sunjun_c") 
declare -A map=(["kkk1"]="value1" ["2"]="value2"  ["3"]="value3")
i=0
while [ $i -le 5 ]
do
   map["key"$i]="$i test$i.tar adf"
   let i=$i+1
done
echo ${map["2"]}  ## value2

echo '${#map[@]}='${#map[@]}            ## print number of Array, ${#map[@]}  OR ${#map[*]}
echo '${map["key2"]}='${map["key2"]}    ## print key-value with key=key1
echo '${map["key2"]}='${map["key2"]}    ## print key-value with key=key1
echo ${!map[@]}  ### ${!map[@]} OR ${!map[*]}:  print all the key 
echo ${map[@]}   ### ${map[@]} OR ${map[*]}:  print all the value

echo "####print the map value list"
for gz in "${map[@]}"   
do
  echo $gz
done

echo "## Array Tst"
array1=([13]="as" ["2"]="sdf" ["3"]="ds")  ## index: 2 3 13
#array1=("as" "sdf" "ds")        ##index: 0, 1, 2  
array1[invalidIndex1]="xx"asdf  ## invalid index "invalidIndex", first element array1[0] will be added
array1[invalidIndex2]="xx"asdf  ## invalid index "invalidIndex", first element array1[0] will be updated
echo ${#array1[@]}
echo ${array1[@]}
echo ${!array1[@]}    ## 0 2 3 13
echo ${array1[2]}     ## print entry with index=2, or index="2" 
