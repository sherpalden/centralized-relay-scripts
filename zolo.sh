#!/bin/bash

source utils.sh

sn=1
src=$(str_to_bytes sui)
dst=$(str_to_bytes icon)
data=$(str_to_bytes hello)
package_id=0x65ac3137937ba87148ce88b9e6dbe33d17bd1ab59881171d11836a8897a396be
gas_id=0x0f0e7e5f061e2ad6eb82193f5062d4755360c77edd3fa9d42202a2338cd23a4e
conn_obj_id=0x75af7e3b48040f151659dd08e256710ff4b3945c3d0cca74fc2cf2b8b53d20b4


tx="sui client call --package $package_id --module conn_module --function new_message --args $sn $src $dst $data $conn_obj_id --gas $gas_id --gas-budget 500000000 --json"

echo "executing: $tx"
result=$($tx) || handle_error "failed to execute call to sui"
echo "Result: $result"

