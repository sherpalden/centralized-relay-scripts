#!/bin/bash

################################### REPO PATHS ###################################

export XCALL_MULTI=$HOME/blockchain/projects/xcall-multi

export ICON_CHAIN_PATH=$HOME/blockchain/chains/gochain-btp
export ARCHWAY_CHAIN_PATH=$HOME/blockchain/chains/archway

##############################     WALLETS     ###################################
export WASM_KEYRING_BACKEND=test
export WASM_GENESIS_KEY=genesis-local
export WASM_RELAYER_KEY=$WASM_GENESIS_KEY

-----------------------------------------------------------------------------------
export EVM_GENESIS_KEY_STORE=$HOME/blockchain/wallets/evm/keystore.json
export EVM_GENESIS_KEY_PASSWORD=password

export EVM_RELAYER_KEY_STORE=$HOME/blockchain/wallets/evm/keystore.json
export EVM_RELAYER_KEY_PASSWORD=password

-----------------------------------------------------------------------------------

export ICON_GENESIS_KEY_STORE=$HOME/blockchain/wallets/icon/genesis-local.json
export ICON_GENESIS_KEY_PASSWORD=gochain

export ICON_RELAYER_KEY_STORE=$HOME/blockchain/wallets/icon/genesis-local.json
export ICON_RELAYER_KEY_PASSWORD=gochain

##############################    NEON-EVM    ###################################
export EVM_GAS_PRICE=10056
export EVM_GAS_LIMIT=200000

export NEON_NODE_URI=https://devnet.neonevm.org
export NEON_NETWORK_ID=0xe9ac0ce.neon
export NEON_DAPP_ADDRESS=0x8e83b1d0a2def6dd3c754a91f8c08cdf8a917f42
export NEON_COMMON_ARGS=" --rpc-url $NEON_NODE_URI --keystore $HOME/blockchain/wallets/evm/neon-keystore.json --password password "


##############################    AVALANCHE-EVM    ###################################
export EVM_GAS_PRICE=10056
export EVM_GAS_LIMIT=200000

export AVALANCHE_NODE_URI=https://rpc-mumbai.maticvigil.com
export AVALANCHE_NETWORK_ID=0x13881.mumbai
export AVALANCHE_DAPP_ADDRESS=0x8e83b1d0a2def6dd3c754a91f8c08cdf8a917f42
export AVALANCHE_COMMON_ARGS=" --rpc-url $AVALANCHE_NODE_URI --keystore $EVM_GENESIS_KEY_STORE --password $EVM_GENESIS_KEY_PASSWORD "

##############################    ARCHWAY    ###################################
export ARCHWAY_BINARY=archwayd
export ARCHWAY_NETWORK_ID=archway
export ARCHWAY_PREFIX=archway
export ARCHWAY_NODE_URI=http://localhost:26657
export ARCHWAY_NODE_GRPC_URI=localhost:443
export ARCHWAY_CHAIN_ID=localnet-1
export ARCHWAY_DENOM=stake
export ARCHWAY_GAS_PRICE=0.025

export ARCHWAY_DAPP_ADDRESS=archway1rl233ncc2tgmz709tnfk5x2lfe5uu9wv0c9vrp

export ARCHWAY_COMMON_ARGS=" --from ${WASM_GENESIS_KEY} --keyring-backend $WASM_KEYRING_BACKEND --node ${ARCHWAY_NODE_URI} --chain-id ${ARCHWAY_CHAIN_ID} --gas-prices ${ARCHWAY_GAS_PRICE}${ARCHWAY_DENOM} --gas auto --gas-adjustment 1.5 "
export ARCHWAY_COMMON_ARGS_V1=" --keyring-backend $WASM_KEYRING_BACKEND --node ${ARCHWAY_NODE_URI} --chain-id ${ARCHWAY_CHAIN_ID} --gas-prices ${ARCHWAY_GAS_PRICE}${ARCHWAY_DENOM} --gas auto --gas-adjustment 1.5 "
	
##############################    SUI    ###################################
export SUI_NODE_URI=https://fullnode.testnet.sui.io:443
export SUI_NODE_WS_URI=ws://fullnode.testnet.sui.io:443
export SUI_CHAIN_ID=sui
export SUI_RELAYER_ADDRESS=0x07304a5d7d1a4763a1cea91f478d24e40aecf1fdbd2f14764d5ad745f4904f85


##############################    ICON    ###################################
export ICON_CHAIN_ID=ibc-icon
export ICON_NID=3
export ICON_NODE_URI=http://localhost:9082/api/v3/
export ICON_DEBUG_NODE=http://localhost:9082/api/v3d
export ICON_NETWORK_ID="0x3.icon"

export ICON_DAPP_ADDRESS=cx345860d03234f71543148561e9a7ddaa602c93d0

export ICON_STEP_LIMIT=100000000000
	
export ICON_COMMON_ARGS=" --uri $ICON_NODE_URI --nid $ICON_NID --step_limit $ICON_STEP_LIMIT --key_store $ICON_GENESIS_KEY_STORE --key_password $ICON_GENESIS_KEY_PASSWORD "

###############################    CONTRACTS     ################################
export EVM_CONTRACT_DIR=$XCALL_MULTI/contracts/evm
export EVM_XCALL_CONTRACT_FILE=$XCALL_MULTI/contracts/evm/contracts/xcall/CallService.sol
export EVM_XCALL_CONTRACT_NAME=CallService

export EVM_CONNECTION_CONTRACT_FILE=$XCALL_MULTI/contracts/evm/contracts/adapters/CentralizedConnection.sol
export EVM_CONNECTION_CONTRACT_NAME=CentralizedConnection

---------------------------------------------------------------------------------
export CW_XCALL=$PWD/artifacts/cw_xcall.wasm
export CW_CENTRALIZED_CONNECTION=$PWD/artifacts/cw_centralized_connection.wasm

---------------------------------------------------------------------------------
export JS_XCALL=$HOME/blockchain/projects/scripts/ibc-relay/artifacts/xcall.jar
# export JS_XCALL=$XCALL_MULTI/contracts/javascore/xcall/build/libs/xcall-0.1.0-optimized.jar
export JS_CENTRALIZED_CONNECTION=$XCALL_MULTI/contracts/javascore/centralized-connection/build/libs/centralized-connection-0.1.0-optimized.jar

---------------------------------------------------------------------------------
export SUI_PKG_RLP=/Users/sherpalden/blockchain/projects/xcall-multi/contracts/sui/libs/sui_rlp/build/sui_rlp/bytecode_modules


####################  CREATE DIRECTORY IF NOT EXISTS #######################
mkdir -p $PWD/env/ARCHWAY
mkdir -p $PWD/env/AVALANCHE
mkdir -p $PWD/env/ICON
mkdir -p $PWD/env/SUI

###############################################################################
############################### BIG MAN BIG BOSS ##############################
###############################################################################
function get() {
    # Using variable indirection to get the value of the variable whose name is passed as an argument
    echo "${!1}"
}

function getPath() {
	echo "$PWD/env/$1/$2"
}