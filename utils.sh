#!/bin/bash

source const.sh

# change to disable stack logs
export PRINT_LOG_STACK=1 # [ 0 , 1 ]

function log_stack() {
	if [[ $PRINT_LOG_STACK == 1 ]];then
	    local cmd=${FUNCNAME[1]}
	    local file=${BASH_SOURCE[1]}
	    if [[ $# > 0 ]]; then cmd="$@"; fi
	    local prefix="$(date '+%Y-%m-%d %H:%M:%S')"
	    awk -v file="$file" -v date="$prefix" -v line=${BASH_LINENO[1]} -v funct=$cmd '
		    BEGIN {
		        printf "\033[0;34m%-20s\033[0;33m%-10s\033[0;36m%-4s\033[0;31m%-19s\n", date, file, line, funct;
		    }
		'
	fi
}

function log() {
	local FILE=${BASH_SOURCE[1]}
	local DATE=$(date +"%Y-%m-%d %H:%M:%S")
	local LINE=$BASH_LINENO
	local FUNC=${FUNCNAME[1]}
	awk -v file="$FILE" -v date="$DATE" -v line=$LINE -v funct=$FUNC -v logx="$1" '
	    BEGIN {
	        printf "\033[0;34m%-20s\033[0;33m%-10s\033[0;36m%-4s\033[0;31m%-19s\033[0m%-50s\n", date, file, line, funct, logx;
	    }
	'
}

function hex_to_decimal() {
    local hex_str=$1
    hex_str=${hex_str#0x}  # Remove '0x' prefix
    hex_str=$(echo "$hex_str" | tr 'a-f' 'A-F')  # Convert to uppercase

    # Correctly use command substitution to assign the output of bc to hex_val
    local hex_val=$(echo "ibase=16; $hex_str" | bc)

    # Echo the value directly
    echo $(($hex_val))
}

function requireFile() {
	local errorMsg=$2
    if [ ! -f "$1" ]; then
    	log $errorMsg
    fi
}

function require_contract_addr() {
	local addr=$1
	if ! [[ $1 =~ ^cx[a-fA-F0-9]{40}$ ]]; then
	    log "invalid contract address $addr"
	    exit 1
	fi
}

function get_sha256sum_hex() {
	local fileLocation=$1
	local checksum=$(openssl dgst -sha256 -hex "$fileLocation" | cut -d ' ' -f 2)
	echo $checksum
}

function get_hash() {
    local val=$1
    local checksum=$(echo -n "$val" | openssl dgst -sha256 -hex | cut -d ' ' -f 2)
    echo $checksum
}

function get_base64_encoded_file_content() {
	local file_path=$1
	# Read file content, generate base64-encoded value, and remove newlines
	local encoded_wasm=$(gzip -c "$file_path" | base64 | tr -d '\n')
	echo $encoded_wasm
}

function get_address_from_keystore() {
    local file_path=$1
    echo $(cat $file_path | jq -r ' .address')
}

function get_address_from_key() {
	local chain=$1
    local key=$2

	binary=$(get ${chain}_BINARY)

    local key_address=$($binary keys list --keyring-backend $WASM_KEYRING_BACKEND --output json | jq -r ".[] | select(.name == \"$key\") | .address")
    echo "$key_address"
}

function is_json() {
    if ! jq -e . >/dev/null 2>&1 <<<"$1"; then
        return 1
    else 
        return 0
    fi
}

function str_to_hex() {
	# Convert the string to hexadecimal representation
	hex_string=$(echo -n "$1" | xxd -p)

	# Add "0x" prefix
	hex_string="0x$hex_string"

	# Print the hexadecimal representation
	echo "$hex_string"
}

function hex_to_str() {
	# Remove "0x" prefix if present
	hex_string="${1#0x}"

	# Convert the hex string to its original string representation
	original_string=$(echo -n "$hex_string" | xxd -r -p)

	# Print the original string
	echo "$original_string"
}

function str_to_bytes(){
	# Get the input string
	input_string="$1"

	# Convert the string to byte array
	byte_array=$(echo -n "$input_string" | od -An -vtu1)

	# Remove leading and trailing spaces
	byte_array=$(echo "$byte_array" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')

	# Replace spaces with commas
	byte_array=$(echo "$byte_array" | tr -s ' ' ',')

	# Add square brackets
	byte_array="[$byte_array]"

	# Print the byte array
	echo "$byte_array"	
}

function handle_error() {
	local error_message="$1"
	echo "Error: $error_message"
	exit 1 >&2
}
