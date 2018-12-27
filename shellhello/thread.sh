#!/bin/bash
THREAD_COUNT=`[[ -z $1 ]] && echo 10`
start=$(date "+%s")
for(( i=0; i<${THREAD_COUNT}; i++))
do
{
  sleep 1
  echo "a=$i"
} &
done
Return=$!
end=$(date "+%s")
echo "Result: $Return"
wait $Return && echo "finished"
echo Take "$((end-start))"

