#!/bin/bash

source const.sh
source utils.sh

RELAY_CFG_FILE=$HOME/.trly/config.yaml
RELAY_CFG_BACKUP_FILE=$HOME/.trly/config_backup.yaml

icon_xcall_address=$(cat $(getPath ICON .xcall)) || handle_error "failed to get icon xcall address"
archway_xcall_address=$(cat $(getPath ARCHWAY .xcall)) || handle_error "failed to get archway xcall address"

icon_connection_address=$(cat $(getPath ICON .centralizedConnection)) || handle_error "failed to get icon centralized connection"
archway_connection_address=$(cat $(getPath ARCHWAY .centralizedConnection)) || handle_error "failed to get archway centralized connection"

icon_relayer_address=$(get_address_from_keystore $ICON_RELAYER_KEY_STORE) || handle_error "failed to get relayer address for icon"
archway_relayer=$(get_address_from_key ARCHWAY $WASM_RELAYER_KEY) || handle_error "failed to get archway relayer address"

cp $RELAY_CFG_FILE $RELAY_CFG_BACKUP_FILE
rm $RELAY_CFG_FILE

cat <<EOF >> $RELAY_CFG_FILE
global:
    timeout: 10s
chains:
    $ICON_NETWORK_ID:
        type: icon
        value:
            chain-id: $ICON_NETWORK_ID
            rpc-url: $ICON_NODE_URI
            network-id: $ICON_NID
            address: $icon_relayer_address
            xcall-address: $icon_xcall_address
            connection-address: $icon_connection_address
    $ARCHWAY_CHAIN_ID:
        type: cosmos
        value:
            chain-id: $ARCHWAY_CHAIN_ID
            nid: $ARCHWAY_NETWORK_ID
            rpc-url: $ARCHWAY_NODE_URI
            grpc-url: $ARCHWAY_NODE_GRPC_URI
            keyring-backend: $WASM_KEYRING_BACKEND
            key-name: $WASM_RELAYER_KEY
            keyring-dir: $HOME/.archway
            address: $archway_relayer
            account-prefix: $ARCHWAY_PREFIX
            xcall-address: $archway_xcall_address
            connection-address: $archway_connection_address
            denomination: $ARCHWAY_DENOM
            gas-prices: $ARCHWAY_GAS_PRICE$ARCHWAY_DENOM
            gas-adjustment: 1.5
            max-gas-amount: 4000000
            min-gas-amount: 20000
            block-interval: 6s
            tx-confirmation-interval: 5s
            broadcast-mode: sync
            sign-mode: SIGN_MODE_DIRECT
            simulate: true
EOF

log "trly config updated!"