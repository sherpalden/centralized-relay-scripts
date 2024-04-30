#!/bin/bash

source const.sh
source utils.sh

SUI_GAS_BUDGET=50000000

XCALL_PATH=./repos/xcall-multi/contracts/sui/xcall
RLP_PATH=./repos/xcall-multi/contracts/sui/libs/sui_rlp
MOCK_DAPP_PATH=./repos/xcall-multi/contracts/sui/mock_dapp


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
    update_file $file_path addresses.sui_rlp 0x0

    sui move build --path $XCALL_PATH

    result=$(sui client publish --gas-budget $SUI_GAS_BUDGET $XCALL_PATH --json) || handle_error "failed to publish package xcall"
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
    xcall_pkg_id=0x23a771b121e17f4ac29e801127f80d7115b97ca1e056faf844af0c8cb535bd7f
    xcall_storage=0xc8f8dfe3d5528b722b4184f18208d4a6b7ad1d0903cafc4bdc29b57690c704b8
    xcall_admin_cap=0x31faf9958abbd7030d7d893e499e43f5ffa1ce461897e4c26cc912d9ffbbba30
    echo $(sui client call \
        --package $xcall_pkg_id \
        --module main \
        --function register_connection \
        --args $xcall_storage $xcall_admin_cap sui centralized \
        --gas 0x3789f3310cd2c556dedd2487d620debc640756cdb36e86dc9ab8d672f85487fd \
        --gas-budget 50000000 \
        --json)
}

function register_xcall() {
    dapp_pkg_id=0x6534a987c20ead36a454ca500f2ec1578c010f99998e255f5d3f60455bd597d7
    xcall_storage=0xc8f8dfe3d5528b722b4184f18208d4a6b7ad1d0903cafc4bdc29b57690c704b8
    dapp_witness_carrier=0x270f69e8fe12a4d25c93a00e412b16cb1236a6d0a166b65951dc004c9d9e5399
    result=$(sui client call \
        --package $dapp_pkg_id \
        --module mock_dapp \
        --function register_xcall \
        --args $xcall_storage $dapp_witness_carrier \
        --gas 0x3789f3310cd2c556dedd2487d620debc640756cdb36e86dc9ab8d672f85487fd \
        --gas-budget 50000000 \
        --json) || handle_error "failed to register xcall on dapp"

    object_type="${dapp_pkg_id}::dapp_state::DappState"
    dapp_state=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId') 

    echo $dapp_state > $(getPath SUI .dappState)  
    log "parsed dapp state : $dapp_state"
}

function send_message() {
    dapp_pkg_id=0x6534a987c20ead36a454ca500f2ec1578c010f99998e255f5d3f60455bd597d7
    xcall_storage=0xc8f8dfe3d5528b722b4184f18208d4a6b7ad1d0903cafc4bdc29b57690c704b8
    dapp_state=0xcce001c26a92463496577406aca3d8cbd73f40ea289da5d25fde0935baa69b9e
    gas_obj_id=0x3789f3310cd2c556dedd2487d620debc640756cdb36e86dc9ab8d672f85487fd
    echo $(sui client call \
        --package $dapp_pkg_id \
        --module mock_dapp \
        --function send_message \
        --args $dapp_state $xcall_storage $gas_obj_id 0x3.icon '[104,101,108,108,111]' \
        --gas $gas_obj_id\
        --gas-budget 50000000 \
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
	send_message)
		send_message $2
	;;
    *)
        echo "Error: unknown action $1"
    ;;
esac