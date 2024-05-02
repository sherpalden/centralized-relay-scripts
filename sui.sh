#!/bin/bash

source const.sh
source utils.sh

SUI_GAS_BUDGET=50000000

GAS_COIN_ID=0x3789f3310cd2c556dedd2487d620debc640756cdb36e86dc9ab8d672f85487fd
GAS_COIN_ID_1=0xdef77b35bb80e3b60465ce919dec3bef53d16bda76c65d9a1ffd120b3affd35e

XCALL_PATH=$PWD/repos/xcall-multi/contracts/sui/xcall
RLP_PATH=$PWD/repos/xcall-multi/contracts/sui/libs/sui_rlp
MOCK_DAPP_PATH=$PWD/repos/xcall-multi/contracts/sui/mock_dapp

function init() {
    cd ./repos
    rm -rf xcall-multi
    git clone -b feat/sui-xcall-contracts git@github.com:icon-project/xcall-multi.git
}

function update_file() {
    file=$1
    key=$2
    val=$3
    dasel put -f "$file" -v "$val" "$key"
}

function deploy_rlp() {
    file_path=$RLP_PATH/MOVE.toml
    update_file $file_path package.published-at 0x0
    update_file $file_path addresses.sui_rlp 0x0

    sui move build --path $RLP_PATH

    result=$(sui client publish --gas-budget $SUI_GAS_BUDGET $RLP_PATH --json) || handle_error "failed to publish package rlp"
    package_id=$(echo $result | jq -r '.objectChanges[] | select(.type == "published") | .packageId')
    echo $package_id > $(getPath SUI .rlp)

    update_file $file_path package.published-at $package_id
    update_file $file_path addresses.sui_rlp $package_id

    log "published package id : $package_id"
}

function deploy_xcall() {
    file_path=$XCALL_PATH/MOVE.toml
    update_file $file_path package.published-at 0x0
    update_file $file_path addresses.xcall 0x0

    sui move build --path $XCALL_PATH

    result=$(sui client publish --gas-budget $SUI_GAS_BUDGET $XCALL_PATH --json) || handle_error "failed to publish package rlp"
    echo "Result: $result"
    package_id=$(echo $result | jq -r '.objectChanges[] | select(.type == "published") | .packageId')

    object_type=$package_id::xcall_state::AdminCap
    admin_cap=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId') 

    object_type=$package_id::xcall_state::Storage
    storage=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId')

    echo $package_id > $(getPath SUI .xcall)
    echo $admin_cap > $(getPath SUI .xcallAdminCap)
    echo $storage > $(getPath SUI .xcallStorage)

    update_file $file_path package.published-at $package_id
    update_file $file_path addresses.xcall $package_id

    log "xcall package id : $package_id"
    log "xcall AdminCap id : $admin_cap"
    log "xcall Storage id : $storage"
}

function deploy_dapp() {
    file_path=$MOCK_DAPP_PATH/MOVE.toml
    update_file $file_path package.published-at 0x0
    update_file $file_path addresses.mock_dapp 0x0

    sui move build --path $MOCK_DAPP_PATH

    result=$(sui client publish --gas-budget $SUI_GAS_BUDGET $MOCK_DAPP_PATH --json) || handle_error "failed to publish package mock_dapp"
    package_id=$(echo $result | jq -r '.objectChanges[] | select(.type == "published") | .packageId')

    object_type=$package_id::mock_dapp::WitnessCarrier
    witness_carrier=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId') 

    echo $package_id > $(getPath SUI .dapp)
    echo $witness_carrier > $(getPath SUI .dappWitnessCarrier)

    update_file $file_path package.published-at $package_id
    update_file $file_path addresses.mock_dapp $package_id

    log "dapp package id : $package_id"
    log "dapp WitnessCarrier id : $package_id"
}

function register_connection() {
    xcall_pkg_id=$(cat $(getPath SUI .xcall))
    xcall_storage=$(cat $(getPath SUI .xcallStorage))
    xcall_admin_cap=$(cat $(getPath SUI .xcallAdminCap))
    echo $(sui client call \
        --package $xcall_pkg_id \
        --module main \
        --function register_connection \
        --args $xcall_storage $xcall_admin_cap sui centralized \
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json)
}

function register_xcall() {
    dapp_pkg_id=$(cat $(getPath SUI .dapp))
    xcall_storage=$(cat $(getPath SUI .xcallStorage))
    dapp_witness_carrier=$(cat $(getPath SUI .dappWitnessCarrier))
    result=$(sui client call \
        --package $dapp_pkg_id \
        --module mock_dapp \
        --function register_xcall \
        --args $xcall_storage $dapp_witness_carrier \
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json) || handle_error "failed to register xcall on dapp"

    object_type="${dapp_pkg_id}::dapp_state::DappState"
    dapp_state=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId') 

    echo $dapp_state > $(getPath SUI .dappState)  
    log "parsed dapp state : $dapp_state"
}

function add_connection() {
    dest_chain=$1
    dest_nid=$(get ${dest_chain}_NETWORK_ID)
    dest_connection_addr=$(cat $(getPath $dest_chain .centralizedConnection))

    dapp_pkg_id=$(cat $(getPath SUI .dapp))
    dapp_state=$(cat $(getPath SUI .dappState))

    tx="sui client call \
        --package $dapp_pkg_id \
        --module mock_dapp \
        --function add_connection \
        --args $dapp_state $dest_nid centralized $dest_connection_addr \
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json"

    echo $($tx)
}

function send_message() {
    dapp_pkg_id=$(cat $(getPath SUI .dapp))
    xcall_storage=$(cat $(getPath SUI .xcallStorage))
    dapp_state=$(cat $(getPath SUI .dappState))
    echo $(sui client call \
        --package $dapp_pkg_id \
        --module mock_dapp \
        --function send_message \
        --args $dapp_state $xcall_storage $GAS_COIN_ID_1 0x3.icon/abc '[104,101,108,108,111]' \
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json)
}

case "$1" in
    init)
        init
    ;;
	deploy)
        case "$2" in
            rlp)
                deploy_rlp
            ;;
			xcall)
                deploy_xcall
            ;;
            dapp)
                deploy_dapp
            ;;
            *)
				echo "Error: unknown contract $2"
			;;
        esac
    ;;
    register)
        case "$2" in
            connection)
                register_connection
            ;;
			xcall)
                register_xcall
            ;;
            *)
				echo "Error: unknown args $2"
			;;
        esac
    ;;
	add_connection)
		add_connection $2
	;;
    send_message)
		send_message $2
	;;
    *)
        echo "Error: unknown action $1"
    ;;
esac