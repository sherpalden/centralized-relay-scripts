#!/bin/bash

source const.sh
source utils.sh

function wait_for_tx_result() {
	local chain=$1
    local tx_hash=$2

	binary=$(get ${chain}_BINARY)
	node_uri=$(get ${chain}_NODE_URI)
	chain_id=$(get ${chain}_CHAIN_ID)

    while :; do
        local res=$($binary query tx $tx_hash --node $node_uri --chain-id $chain_id 2>&1)
		if [[ $res == *"tx ($tx_hash) not found"* ]]; then
            echo "Transaction is still being processed. Waiting..." >&2
            sleep 1 
        else
			local tx_result=$($binary query tx $tx_hash --node $node_uri --chain-id $chain_id --output json)
            echo "$tx_result"  # This will be captured by the caller
            break  # Exit the loop
        fi
    done
}

function check_txn_result() {
	log_stack
	local chain=$1
	local tx_hash=$2

	local tx_result=$(wait_for_tx_result $chain $tx_hash) || handle_error "failed to wait for tx result"

	local code=$(echo $tx_result | jq -r .code) || handle_error "failed to get code from tx result"

	if [ "$code" == "0" ]; then 
		log "txn successful"
	else
		handle_error "txn failure: $(echo $tx_result | jq -r .raw_log)"
	fi
}

function deploy_contract() {
	log_stack

	local chain=$1
	local wasm_file=$2
	local addr_loc=$3
	local init_args=$4

	binary=$(get ${chain}_BINARY)
	common_args=$(get ${chain}_COMMON_ARGS)
	node_uri=$(get ${chain}_NODE_URI)

	requireFile ${wasm_file} "${wasm_file} does not exist"
	log "deploying contract ${wasm_file##*/}"

	local store_res=$($binary tx wasm store $wasm_file $common_args --yes --output json --broadcast-mode sync)
	local store_tx_hash=$(echo $store_res | jq -r '.txhash')
	echo "Store Tx Hash: $store_tx_hash"
	local store_tx_result=$(wait_for_tx_result $chain $store_tx_hash)
	local code_id=$(echo $store_tx_result | jq -r '.logs[0].events[] | select(.type=="store_code") | .attributes[] | select(.key=="code_id") | .value')
	log "received code id ${code_id}"

	local admin=$($binary keys show $WASM_GENESIS_KEY --keyring-backend $WASM_KEYRING_BACKEND --output=json | jq -r .address)
	local init_res=$($binary tx wasm instantiate $code_id $init_args $common_args --label "github.com/izyak/icon-ibc" --admin $admin -y)

	while :; do
		local addr=$($binary query wasm lca "${code_id}" --node $node_uri --output json | jq -r '.contracts[-1]') 
		if [ "$addr" != "null" ]; then
	        break
	    fi
	    sleep 2
	done

	local contract=$($binary query wasm lca "${code_id}" --node $node_uri --output json | jq -r '.contracts[-1]')
	log "${wasm_file##*/} deployed at : ${contract}"
	echo $contract > $addr_loc
	sleep 5
}

function execute_contract() {
	log_stack
	local chain=$1
	local contract_addr=$2
	local call_params_json_str=$3
	log "method and params $call_params"

	binary=$(get ${chain}_BINARY)
	node_uri=$(get ${chain}_NODE_URI)
	common_args=$(get ${chain}_COMMON_ARGS)

	local tx_hash=$($binary tx wasm execute $contract_addr $call_params_json_str $common_args -y --output json | jq -r .txhash) || handle_error "failed to execute contract"
	log "tx_hash : $tx_hash"
	check_txn_result $chain $tx_hash
}

function deploy_xcall() {
	chain=$1
	network_id=$(get ${chain}_NETWORK_ID)
	denom=$(get ${chain}_DENOM)

	xcall_addr_path=$(getPath $chain .xcall)

	local xcall_args="{\"network_id\":\"$network_id\",\"denom\":\"$denom\"}"

	deploy_contract $chain $CW_XCALL $xcall_addr_path $xcall_args
}

function deploy_centralized_connection() {
	chain=$1
	network_id=$(get ${chain}_NETWORK_ID)
	denom=$(get ${chain}_DENOM)

	local xcall_addr=$(cat $(getPath $chain .xcall))
	local relayer=$(get_address_from_key $chain $WASM_RELAYER_KEY)

	local connection_args="{\"relayer\":\"$relayer\",\"xcall_address\":\"$xcall_addr\",\"denom\":\"$denom\"}" 

	deploy_contract $chain $CW_CENTRALIZED_CONNECTION $(getPath $chain .centralizedConnection) $connection_args
}

function send_message() {
    local src_chain=$1
    local dest_chain=$2

    local dst_network_id=$(get ${dest_chain}_NETWORK_ID)
    local dst_dapp_address=$(get ${dest_chain}_DAPP_ADDRESS)

    local src_connection_address=$(cat $(getPath $src_chain .centralizedConnection))
    local dst_connection_address=$(cat $(getPath $dest_chain .centralizedConnection))

    local src_xcall_address=$(cat $(getPath $src_chain .xcall))

	local call_params="{\"send_call_message\":{\"to\":\"$dst_network_id/$dst_dapp_address\",\"data\":[1,2,3,4,5],\"sources\":[\"$src_connection_address\"],\"destinations\":[\"$dst_connection_address\"]}}"

	execute_contract $src_chain $src_xcall_address $call_params
}


function start_node_archway() {
	cd $ARCHWAY_CHAIN_PATH
	TAG=$(git describe --tags --abbrev=0) docker compose up -d
}

function stop_node_archway() {
	cd $ARCHWAY_CHAIN_PATH
  	TAG=$(git describe --tags --abbrev=0) docker compose down
}

case "$1" in
	start_node)
		case "$2" in
			archway)
				start_node_archway
			;;
			*)
				echo "Error: unknown node $2"
			;;
		esac
	;;
	stop_node)
		case "$2" in
			archway)
				stop_node_archway
			;;
			*)
				echo "Error: unknown node $2"
			;;
		esac
	;;
	deploy)
        case "$2" in
            xcall)
                deploy_xcall $3
            ;;
			connection)
                deploy_centralized_connection $3
            ;;
            *)
				echo "Error: unknown contract $2"
			;;
        esac
    ;;
	send_message)
		send_message $2 $3
	;;
    *)
        echo "Error: unknown action $1"
    ;;
esac