#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script is designed to be run in the org3cli container as the
# first step of the EYFN tutorial.  It creates and submits a
# configuration transaction to add org3 to the network previously
# setup in the BYFN tutorial.
#

CHANNEL_NAME="$1"
DELAY="$2"
LANGUAGE="$3"
TIMEOUT="$4"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${LANGUAGE:="golang"}
: ${TIMEOUT:="10"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5
BASE_PATH=/opt/gopath/src/github.com/hyperledger/fabric
ORDERER_CA=${BASE_PATH}/peer/crypto/ordererOrganizations/belink.com/orderers/orderer.belink.com/msp/tlscacerts/tlsca.belink.com-cert.pem
CORE_PEER_TLS_ENABLED=true


# import utils
. scripts/utils.sh



echo "Signing config transaction"
echo
signConfigtxAsPeerOrg 1 config_update_in_envelope.pb
echo
signConfigtxAsPeerOrg 2 config_update_in_envelope.pb
echo
signConfigtxAsPeerOrg 3 config_update_in_envelope.pb

echo
echo "========= Submitting transaction from a orderer which also signs it ========= "
echo
setOrdererGlobals
set -x
peer channel update -f config_update_in_envelope.pb -c ${CHANNEL_NAME} -o orderer.belink.com:7050 --tls --cafile ${ORDERER_CA}
set +x

echo
echo "========= Config transaction to add org3 to network submitted! =========== "
echo

exit 0
