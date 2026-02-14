#!/bin/bash

nc -vz 192.168.1.21 3010
curl -I http://192.168.1.21:3010/
curl -I http://192.168.1.21:3010/api/
curl -I http://192.168.1.21:3010/api/schema/view/


# curl -vk https://192.168.1.21:3010/ 2>&1 | head -n 30
# curl -I http://192.168.1.21:3010/ | sed -n '1,20p'
