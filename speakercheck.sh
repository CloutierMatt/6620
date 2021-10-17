#!/bin/bash

ID="name='Line Out Jack'"
MODEL=$(sudo dmidecode -s system-product-name)

echo $MODEL


for i in {1..25}
do
        VALUE=$(amixer -c 0 cget numid=$i | grep -i -o "name='Line Out Jack'")
        
       if [ "$VALUE" = "$ID" ]; then
          echo $VALUE
       fi


        
done

#case $MODEL in
#        MS-A923)
#                amixer -c 0 cget numid=18 | grep "on" || "off"
#                ;;
#        TE-AC7D11)
#                amixer -c 0 cget numid=18 | grep "on" || "off"
#                ;;
#        HP\ 15\ Notebook\ PC)
#                echo "ばか"
#                ;;
#esac
