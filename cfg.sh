#!/bin/bash

source const.sh
source utils.sh

RELAY_CFG_FILE=$HOME/.centralized-relay/config.yaml
RELAY_CFG_BACKUP_FILE=$HOME/.centralized-relay/config_backup.yaml


sui_xcall_address=$(cat $(getPath SUI .xcall)) || handle_error "failed to get sui xcall address"
sui_dapp_address=$(cat $(getPath SUI .mockDapp)) || handle_error "failed to get sui dapp address"

sui_xcall_storage_id=$(cat $(getPath SUI .xcallStorage)) || handle_error "failed to get sui xcall storage address"
sui_dapp_state_id=$(cat $(getPath SUI .mockDappState)) || handle_error "failed to get sui dapp state address"
sui_dapp_cap_id=$(cat $(getPath SUI .mockDappCapId)) || handle_error "failed to get sui dapp cap id"

icon_xcall_address=$(cat $(getPath ICON .xcall)) || handle_error "failed to get icon xcall address"
avalanche_xcall_address=$(cat $(getPath AVALANCHE .xcall)) || handle_error "failed to get avalanche xcall address"
archway_xcall_address=$(cat $(getPath ARCHWAY .xcall)) || handle_error "failed to get archway xcall address"

icon_connection_address=$(cat $(getPath ICON .centralizedConnection)) || handle_error "failed to get icon centralized connection"
avalanche_connection_address=$(cat $(getPath AVALANCHE .centralizedConnection)) || handle_error "failed to get avalanche centralized connection"
archway_connection_address=$(cat $(getPath ARCHWAY .centralizedConnection)) || handle_error "failed to get archway centralized connection"

evm_relayer_address=$(get_address_from_keystore $EVM_RELAYER_KEY_STORE) || handle_error "failed to get relayer address for evm"
icon_relayer_address=$(get_address_from_keystore $ICON_RELAYER_KEY_STORE) || handle_error "failed to get relayer address for icon"

archway_relayer=$(get_address_from_key ARCHWAY $WASM_RELAYER_KEY) || handle_error "failed to get archway relayer address"

cp $RELAY_CFG_FILE $RELAY_CFG_BACKUP_FILE
rm $RELAY_CFG_FILE

cat <<EOF >> $RELAY_CFG_FILE
global:
  timeout: 10s
  kms-key-id: 5b52e346-0caf-4373-baa4-98b138e081b1
chains:
  sui:
    type: sui
    value:
      chain-id: sui
      nid: sui
      rpc-url: $SUI_NODE_URI
      address: $SUI_RELAYER_ADDRESS
      xcall-package-id: $sui_xcall_address
      xcall-storage-id: $sui_xcall_storage_id

      dapp-package-id: $sui_dapp_address
      dapp-treasury-cap-carrier: $SUI_DAPP_TREASURY_CAP_CARRIER
      dapp-modules:
        - name: mock_dapp
          cap-id: $sui_dapp_cap_id
          config-id: $sui_dapp_state_id

      gas-limit: 5000000

  # avalanche:
  #   type: evm
  #   value:
  #     rpc-url: $AVALANCHE_NODE_URI
  #     websocket-url: wss://neon-evm-devnet.drpc.org
  #     start-height: 0
  #     address: $evm_relayer_address
  #     gas-price: $EVM_GAS_PRICE
  #     gas-limit: $EVM_GAS_LIMIT
  #     contracts:
  #       xcall: $avalanche_xcall_address
  #       connection: $avalanche_connection_address
  #     nid: $AVALANCHE_NETWORK_ID
  #     finality-block: 10
  #     block-interval: 2s

  # neon:
  #   type: evm
  #   value:
  #       rpc-url: https://devnet.neonevm.org
  #       websocket-url: wss://neon-evm-devnet.drpc.org
  #       verifier-rpc-url: ""
  #       start-height: 0
  #       address: 0x918f8e141bc7b886a614e711115d6ab649a7fe16
  #       gas-price: 300000000000
  #       gas-min: 0
  #       gas-limit: 2000000
  #       contracts:
  #           connection: 0x76A614Fc699765558956818aD09AA1B8cEc9c349
  #           xcall: 0x3B6E7c52d2b493A6a2c29aFf495e83dC16066844
  #       concurrency: 0
  #       finality-block: 10
  #       block-interval: 400ms
  #       nid: 0xe9ac0ce.neon

  icon:
    type: icon
    value:
      rpc-url: $ICON_NODE_URI
      start-height: 0
      address: $icon_relayer_address
      contracts:
        xcall: $icon_xcall_address
        connection: $icon_connection_address
      network-id: $ICON_NID
      nid: $ICON_NETWORK_ID
      step-min: 1
      step-limit: 100000000000

  # solana:
  #   type: solana
  #   value:
  #     rpc-url: http://localhost:8899
  #     start-height: 0
  #     address: 7GoW5ACKgsKcjWKnfPXeGyZHMSNBJkqHFwjt5ex2i73z
  #     xcall-state-account: 98jWod7uQK1kzfT3APyQ6DrDeQT8Hmu3PNm5n4T4ttoG
  #     xcall-idl: 3fFhJNrxpdnKcxsY9sem81bg3VPQL5FySwzg99354spR
  #     nid: solana 
  #     gas-limit: 1000
  # archway:
  #   type: cosmos
  #   value:
  #     chain-id: $ARCHWAY_CHAIN_ID
  #     nid: $ARCHWAY_NETWORK_ID
  #     rpc-url: $ARCHWAY_NODE_URI
  #     grpc-url: $ARCHWAY_NODE_GRPC_URI
  #     keyring-backend: memory
  #     address: $archway_relayer
  #     account-prefix: $ARCHWAY_PREFIX
  #     start-height: 0
  #     contracts:
  #       xcall: $archway_xcall_address
  #       connection: $archway_connection_address
  #     denomination: $ARCHWAY_DENOM
  #     gas-prices: $ARCHWAY_GAS_PRICE$ARCHWAY_DENOM
  #     gas-adjustment: 1.5
  #     max-gas-amount: 4000000
  #     min-gas-amount: 20000
  #     block-interval: 6s
  #     tx-confirmation-interval: 5s
  #     broadcast-mode: sync
  #     sign-mode: SIGN_MODE_DIRECT
  #     simulate: true
  #     finality-block: 0
EOF

log "relay config updated!"