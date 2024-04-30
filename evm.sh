#!/bin/bash

source const.sh
source utils.sh

function deploy_contract() {
    local chain=$1
    local contract_file=$2
    local contract_name=$3
    local addr_loc=$4
    local init_args=$5

    local common_args=$(get ${chain}_COMMON_ARGS)

    cd $EVM_CONTRACT_DIR

    log "deploying $contract_name to chain $chain"

    local action="forge create $contract_file:$contract_name --constructor-args $init_args $common_args --json"
    local output=$($action)

    local transaction_hash=$(echo $output | jq -r '.transactionHash')
    log "tx hash: $transaction_hash"

    local contract_address=$(echo $output | jq -r '.deployedTo')

    # Check if the deployment was successful
    if [ -z "$contract_address" ] || [ "$contract_address" == "null" ]; then
        cd -
        handle_error "failed to deploy contract: $contract_name"
    fi

    log "$contract_name deployed at: $contract_address"

    echo $contract_address > $addr_loc

    cd -
}

function init_xcall() {
    local chain=$1

    local network_id=$(get ${chain}_NETWORK_ID)
    local common_args=$(get ${chain}_COMMON_ARGS)

    local xcall_address=$(cat $(getPath $chain .xcall))

    log "initializing xcall"

    local output=$(cast send $xcall_address "initialize(string)" "$network_id" $common_args --json) || handle_error "failed to init xcall"
    
    local transaction_hash=$(echo $output | jq -r '.transactionHash')
    log "tx hash: $transaction_hash"

    local status=$(echo $output | jq -r '.status')

    if [ "$status" != "0x1" ]; then
        handle_error "failed to initialize xcall"
    fi

    log "xcall initialization successful"
}

function init_centralized_connection() {
    local chain=$1
    
    local common_args=$(get ${chain}_COMMON_ARGS)

    local xcall_address=$(cat $(getPath $chain .xcall))
    local connection_address=$(cat $(getPath $chain .centralizedConnection))

    local relayer_address=$(get_address_from_keystore $EVM_RELAYER_KEY_STORE)

    log "initializing centralized connection"

    local output=$(cast send $connection_address "initialize(address _relayer, address _xCall)" "$relayer_address" "$xcall_address" $common_args --json) || handle_error "failed to init centralized connection"
    
    local transaction_hash=$(echo $output | jq -r '.transactionHash')
    log "tx hash: $transaction_hash"

    local status=$(echo $output | jq -r '.status')

    if [ "$status" != "0x1" ]; then
        handle_error "failed to initialize centralized connection"
    fi

    log "centralized connection initialization successful"
}

function deploy_xcall() {
    local chain=$1

    local network_id=$(get ${chain}_NETWORK_ID)

    local addr_loc=$(getPath $chain .xcall)

    local init_args="$network_id"

    deploy_contract $chain $EVM_XCALL_CONTRACT_FILE $EVM_XCALL_CONTRACT_NAME $addr_loc $init_args
}

function deploy_centralized_connection() {
    local chain=$1

    local addr_loc=$(getPath $chain .centralizedConnection)

    local xcall_addr=$(cat $(getPath $chain .xcall))

    local relayer_address=$(get_address_from_keystore $EVM_RELAYER_KEY_STORE)

    local init_args="$relayer_addr $xcall_addr"

    deploy_contract $chain $EVM_CONNECTION_CONTRACT_FILE $EVM_CONNECTION_CONTRACT_NAME $addr_loc $init_args
}

function send_message() {
    local src_chain=$1
    local dest_chain=$2

    local src_common_args=$(get ${src_chain}_COMMON_ARGS)

    local dst_network_id=$(get ${dest_chain}_NETWORK_ID)
    local dst_dapp_address=$(get ${dest_chain}_DAPP_ADDRESS)

    local src_connection_address=$(cat $(getPath $src_chain .centralizedConnection))
    local dst_connection_address=$(cat $(getPath $dest_chain .centralizedConnection))

    local src_xcall_address=$(cat $(getPath $src_chain .xcall))

    local method_signature="sendCallMessage(string memory _to, bytes memory _data, bytes memory _rollback, string[] memory sources, string[] memory destinations)"
    local _to="$dst_network_id/$dst_dapp_address"
    local _data="0x90"
    local _rollback=""
    local _sources="[\"$src_connection_address\"]"
    local _destinations="[\"$dst_connection_address\"]"

    log "sending message from $src_chain to $dest_chain"
    local result=$(cast send "$src_xcall_address" "$method_signature" "$_to" "$_data" "$_rollback" "$_sources" "$_destinations" \
        $src_common_args --json) || handle_error "failed to send message from $src_chain to $dest_chain"

    local tx_hash=$(echo $result | jq -r '.transactionHash')
    log "tx hash: $tx_hash"

    local status=$(echo $result | jq -r '.status')

    if [ "$status" != "0x1" ]; then
        handle_error "failed to send message"
    fi

    log "message send successful"
}

case "$1" in
	deploy)
        case "$2" in
            xcall)
                deploy_xcall $3
                init_xcall $3
            ;;
			connection)
                deploy_centralized_connection $3
                init_centralized_connection $3
            ;;
            *)
				echo "Error: unknown contract $2"
			;;
        esac
    ;;
    init)
        case "$2" in
            xcall)
                init_xcall $3
            ;;
			connection)
                init_centralized_connection $3
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