#!/bin/bash

source const.sh
source utils.sh

function icon_wait_tx() {
    local tx_hash="$1"
    if [[ -z "$tx_hash" ]]; then
        handle_error "tx_hash is empty"
    fi

    log "tx hash: $tx_hash"

    local tx_receipt
    local tx="goloop rpc --uri $ICON_NODE_URI txresult $tx_hash"
    while :; do
        tx_receipt=$(eval "$tx" 2>/dev/null)
        if [[ $tx_receipt == *"Error:"* ]] || [[ $tx_receipt == "" ]]; then
            echo "Transaction is still being processed. Waiting..." >&2
            sleep 1 
        else
            break 
        fi
    done

    local status=$(jq -r <<<"$tx_receipt" .status)
    if [[ $status == "0x1" ]]; then
        log "txn success with status: $status"
    else
        handle_error "txn failed with status: $status"
    fi
}


function save_address() {
    log_stack
    local ret=1
    local tx_hash=$1
    local addr_loc=$2
    [[ -z $tx_hash ]] && return
    local txr=$(goloop rpc --uri "$ICON_NODE_URI" txresult "$tx_hash" 2>/dev/null)
    local score_address=$(jq <<<"$txr" -r .scoreAddress)
    echo $score_address > $addr_loc
    log "contract address : $score_address"
}

function deploy_contract() {
	log_stack
	local jarFile=$1
    local addrLoc=$2
	requireFile $jarFile "$jarFile does not exist"
	log "deploying contract ${jarFile##*/}"

	local params=()
    for i in "${@:3}"; do params+=("--param $i"); done

    local tx_hash=$(
        goloop rpc sendtx deploy $jarFile \
	    	--content_type application/java \
	    	--to cx0000000000000000000000000000000000000000 \
	    	$ICON_COMMON_ARGS \
	    	${params[@]} | jq -r .
    )
   	icon_wait_tx "$tx_hash"
    save_address "$tx_hash" $addrLoc
}

function deploy_xcall() {
    deploy_contract $JS_XCALL $(getPath ICON .xcall) networkId=$ICON_NETWORK_ID
}

function deploy_centralized_connection() {
    local xcall_addr=$(cat $(getPath ICON .xcall))
    local relayer_addr=$(get_address_from_keystore $ICON_RELAYER_KEY_STORE)

    deploy_contract $JS_CENTRALIZED_CONNECTION $(getPath ICON .centralizedConnection) _xCall=$xcall_addr _relayer=$relayer_addr
}

function send_message() {
    local dest_chain=$1

    local dst_network_id=$(get ${dest_chain}_NETWORK_ID)
    local dst_dapp_address=$(get ${dest_chain}_DAPP_ADDRESS)

    local src_connection_address=$(cat $(getPath ICON .centralizedConnection))
    local dst_connection_address=$(cat $(getPath $dest_chain .centralizedConnection))

    local src_xcall_address=$(cat $(getPath ICON .xcall))

    local param="{\"params\":{\"_to\":\"$dst_network_id/$dst_dapp_address\",\"_data\":\"0x90\",\"_sources\":[\"$src_connection_address\"],\"_destinations\":[\"$dst_connection_address\"]}}"
	
    local tx_hash=$(goloop rpc sendtx call \
	    --to $src_xcall_address \
	    --method sendCallMessage \
	    --raw $param \
        $ICON_COMMON_ARGS | jq -r .) || handle_error "failed to send message from icon to $dest_chain"

    icon_wait_tx "$tx_hash"
}

function start_node() {
	cd $ICON_CHAIN_PATH
	make ibc-ready
}

function stop_node() {
	cd $ICON_CHAIN_PATH
	make stop
}

case "$1" in
    start_node)
		start_node
	;;
	stop_node)
		stop_node
	;;
	deploy)
        case "$2" in
            xcall)
                deploy_xcall
            ;;
			connection)
                deploy_centralized_connection
            ;;
            *)
				echo "Error: unknown contract $2"
			;;
        esac
    ;;
	send_message)
		send_message $2
	;;
    *)
        echo "Error: unknown action $1"
    ;;
esac