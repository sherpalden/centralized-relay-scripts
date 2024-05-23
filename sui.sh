#!/bin/bash

source const.sh
source utils.sh

SUI_GAS_BUDGET=500000000

GAS_COIN_ID=0xba311cc48a4f5b1e15cc7ac91da4303ab3856122660e6a7db6b44296923d3c51
GAS_COIN_ID_1=0x6366bc7935fe392b8988e848328bc9cdc9a496c46dfd2a6e9c927b75fd1228f9

XCALL_PATH=$PWD/repos/xcall-multi/contracts/sui/xcall
RLP_PATH=$PWD/repos/xcall-multi/contracts/sui/libs/sui_rlp
MOCK_DAPP_PATH=$PWD/repos/xcall-multi/contracts/sui/mock_dapp

BALACNED_PATH=$PWD/repos/balanced-move-contracts


function init() {
    cd ./repos
    rm -rf xcall-multi
    git clone -b feat/sui-xcall-contracts git@github.com:icon-project/xcall-multi.git

    rm -rf balanced-move-contracts
    git clone -b dev git@github.com:balancednetwork/balanced-move-contracts.git
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

    result=$(sui client publish --skip-dependency-verification --gas-budget $SUI_GAS_BUDGET $RLP_PATH --json)
    echo "result: $result"
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

    result=$(sui client publish --skip-dependency-verification --gas-budget $SUI_GAS_BUDGET $XCALL_PATH --json)
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

function deploy_mock_dapp() {
    file_path=$MOCK_DAPP_PATH/MOVE.toml
    update_file $file_path package.published-at 0x0
    update_file $file_path addresses.mock_dapp 0x0

    sui move build --path $MOCK_DAPP_PATH

    result=$(sui client publish --skip-dependency-verification --gas-budget $SUI_GAS_BUDGET $MOCK_DAPP_PATH --json) || handle_error "failed to publish package mock_dapp"
    package_id=$(echo $result | jq -r '.objectChanges[] | select(.type == "published") | .packageId')

    object_type=$package_id::mock_dapp::WitnessCarrier
    witness_carrier=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId') 

    echo $package_id > $(getPath SUI .mockDapp)
    echo $witness_carrier > $(getPath SUI .mockDappWitnessCarrier)

    update_file $file_path package.published-at $package_id
    update_file $file_path addresses.mock_dapp $package_id

    log "dapp package id : $package_id"
    log "dapp WitnessCarrier id : $witness_carrier"
}

function deploy_balanced() {
    file_path=$BALACNED_PATH/MOVE.toml
    update_file $file_path package.published-at 0x0
    update_file $file_path addresses.balanced 0x0

    sui move build --path $BALACNED_PATH

    result=$(sui client publish --skip-dependency-verification --gas-budget $SUI_GAS_BUDGET $BALACNED_PATH --json)
    echo $result
    package_id=$(echo $result | jq -r '.objectChanges[] | select(.type == "published") | .packageId')

    object_type=$package_id::xcall_manager::AdminCap
    admin_cap=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId') 


    object_type=$package_id::xcall_manager::WitnessCarrier
    witness_carrier=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId') 

    echo $package_id > $(getPath SUI .dapp)
    echo $witness_carrier > $(getPath SUI .dappWitnessCarrier)
    echo $admin_cap > $(getPath SUI .dappAdminCap)

    update_file $file_path package.published-at $package_id
    update_file $file_path addresses.balanced $package_id

    log "dapp package id : $package_id"
    log "dapp AdminCap id : $admin_cap"
    log "dapp WitnessCarrier id : $witness_carrier"
}

function configure_balanced() {
    dest_chain=$1
    dest_nid=$(get ${dest_chain}_NETWORK_ID)
    dest_connection_addr=$(cat $(getPath $dest_chain .centralizedConnection))

    dest_dapp_addr=$(cat $(getPath $dest_chain .dapp))


    dapp_pkg_id=$(cat $(getPath SUI .dapp))

    dapp_admin_cap=$(cat $(getPath SUI .dappAdminCap))
    xcall_state=$(cat $(getPath SUI .xcallStorage))
    dapp_witness_carrier=$(cat $(getPath SUI .dappWitnessCarrier))
    icon_governance=$dest_dapp_addr
    sources=["centralized"]
    destinations=["$dest_connection_addr"]

    tx="sui client call \
        --package $dapp_pkg_id \
        --module xcall_manager \
        --function configure \
        --args $dapp_admin_cap $xcall_state $dapp_witness_carrier $icon_governance $sources $destinations 1 \
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json"

    echo "executing tx: $tx"

    result=$($tx)

    echo $result

    object_type="${dapp_pkg_id}::xcall_manager::Config"
    dapp_state=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId') 

    echo $dapp_state > $(getPath SUI .dappState)  
    log "parsed dapp state : $dapp_state"

    dapp_state_object=$(sui client object $dapp_state --json)
    dapp_cap_id=$(echo "$dapp_state_object" | jq -r '.content.fields.id_cap.fields.id.id')

    echo $dapp_cap_id > $(getPath SUI .dappCapId)  
    log "parsed dapp cap id : $dapp_cap_id"
}


function configure_nid() {
    xcall_pkg_id=$(cat $(getPath SUI .xcall))
    xcall_storage=$(cat $(getPath SUI .xcallStorage))
    xcall_admin_cap=$(cat $(getPath SUI .xcallAdminCap))
    tx="sui client call \
        --package $xcall_pkg_id \
        --module main \
        --function configure_nid \
        --args $xcall_storage $xcall_admin_cap $SUI_NETWORK_ID \
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json"
    echo "executing: $tx"
    echo $($tx)
}

function register_connection() {
    xcall_pkg_id=$(cat $(getPath SUI .xcall))
    xcall_storage=$(cat $(getPath SUI .xcallStorage))
    xcall_admin_cap=$(cat $(getPath SUI .xcallAdminCap))
    tx="sui client call \
        --package $xcall_pkg_id \
        --module main \
        --function register_connection \
        --args $xcall_storage $xcall_admin_cap sui centralized \
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json"
    echo "executing: $tx"
    echo $($tx)
}

function register_xcall_mock_dapp() {
    dapp_pkg_id=$(cat $(getPath SUI .mockDapp))
    xcall_storage=$(cat $(getPath SUI .xcallStorage))
    dapp_witness_carrier=$(cat $(getPath SUI .mockDappWitnessCarrier))
    result=$(sui client call \
        --package $dapp_pkg_id \
        --module mock_dapp \
        --function register_xcall \
        --args $xcall_storage $dapp_witness_carrier \
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json)
    
    echo "result: $result"

    object_type="${dapp_pkg_id}::dapp_state::DappState"
    dapp_state=$(echo "$result" | jq -r --arg object_type "$object_type" '.objectChanges[] | select(.objectType == $object_type) | .objectId') 

    dapp_state_object=$(sui client object $dapp_state --json)
    dapp_cap_id=$(echo "$dapp_state_object" | jq -r '.content.fields.xcall_cap.fields.id.id')

    echo $dapp_cap_id > $(getPath SUI .mockDappCapId)  
    echo $dapp_state > $(getPath SUI .mockDappState)  
    log "parsed dapp state : $dapp_state"
    log "parsed dapp cap id : $dapp_cap_id"
}

function add_connection_mock_dapp() {
    dest_chain=$1
    dest_nid=$(get ${dest_chain}_NETWORK_ID)
    dest_connection_addr=$(cat $(getPath $dest_chain .centralizedConnection))

    dapp_pkg_id=$(cat $(getPath SUI .mockDapp))
    dapp_state=$(cat $(getPath SUI .mockDappState))

    tx="sui client call \
        --package $dapp_pkg_id \
        --module mock_dapp \
        --function add_connection \
        --args $dapp_state $dest_nid centralized $dest_connection_addr \
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json"

    echo "executing tx: $tx"

    echo $($tx)
}

function send_message() {
    dest_chain=$1
    dapp_pkg_id=$(cat $(getPath SUI .mockDapp))
    xcall_storage=$(cat $(getPath SUI .xcallStorage))
    dapp_state=$(cat $(getPath SUI .mockDappState))

    dest_nid=$(get ${dest_chain}_NETWORK_ID)
    dest_dapp=$(cat $(getPath $dest_chain .dapp))

    dest_id=$dest_nid/$dest_dapp

    # msg=0x68656c6c6f207468657265
    msg=0x7265706c792d726573706f6e7365
    # msg=0x4d6f73742070656f706c65206172652066616d696c69617220776974682074686520646563696d616c2c206f7220626173652d31302c2073797374656d206f66206e756d626572732028616c6c20706f737369626c65206e756d626572732063616e206265206e6f7461746564207573696e6720746865203130206469676974732c20302c312c322c332c342c352c362c372c382c39292e2057697468206f6e6c79203130206469676974732c20657874726120646967697473206e65656420746f2062652075736564206174206365727461696e20696e74657276616c7320746f20636f72726563746c79206e6f746174652061206e756d6265722e20466f72206578616d706c652c20746865206e756d626572203432332c3030342075736573207477696365206173206d7563682064696769747320617320746865206e756d626572203936312e0d0a0d0a


    tx="sui client call \
        --package $dapp_pkg_id \
        --module mock_dapp \
        --function send_message \
        --args $dapp_state $xcall_storage $GAS_COIN_ID_1 $dest_id $msg 0x68656c6c6f\
        --gas $GAS_COIN_ID \
        --gas-budget $SUI_GAS_BUDGET \
        --json"
    echo "executing: $tx"
    echo $($tx)
}

function setup_sui_balanced() {
    deploy_rlp
    sleep 3 

    deploy_xcall
    sleep 3

    register_connection
    sleep 3

    deploy_balanced
    sleep 3

    configure_balanced ICON
}

function setup_sui_mock_dapp() {
    deploy_rlp
    sleep 3 

    deploy_xcall
    sleep 3

    configure_nid
    sleep 3

    register_connection
    sleep 3

    deploy_mock_dapp
    sleep 3

    register_xcall_mock_dapp
    sleep 3

    add_connection_mock_dapp ICON
}


case "$1" in
    init)
        init
    ;;
    configure_balanced)
        configure_balanced $2
    ;;
    setup)
        setup_sui_mock_dapp
    ;;
	deploy)
        case "$2" in
            rlp)
                deploy_rlp
            ;;
			xcall)
                deploy_xcall
            ;;
            mock_dapp)
                deploy_mock_dapp
            ;;
            balanced)
                deploy_balanced
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
                register_xcall_mock_dapp
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