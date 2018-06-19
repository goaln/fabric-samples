#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Build your first network (BYFN) end-to-end test"
echo
CHANNEL_NAME="$1"
DELAY="$2"
: ${CHANNEL_NAME:="mychannel"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/belink.com/orderers/orderer.belink.com/msp/tlscacerts/tlsca.belink.com-cert.pem

echo "Channel name : "$CHANNEL_NAME

# verify the result of the end-to-end test
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
		echo
   		exit 1
	fi
}

setOrdererGlobals() {
        CORE_PEER_LOCALMSPID="OrdererMSP"
        CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/belink.com/orderers/orderer.belink.com/msp/tlscacerts/tlsca.belink.com-cert.pem
        CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/belink.com/users/Admin@belink.com/msp
}

setGlobals () {

	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="BelinkMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain.belink.com/peers/peer0.blockchain.belink.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain.belink.com/users/Admin@blockchain.belink.com/msp
		if [ $1 -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.blockchain.belink.com:7051
		else
			CORE_PEER_ADDRESS=peer1.blockchain.belink.com:7051
			CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain.belink.com/users/Admin@blockchain.belink.com/msp
		fi
	elif [ $1 -eq 2 -o $1 -eq 3 ] ; then
		CORE_PEER_LOCALMSPID="XinWangMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain.xinwang.com/peers/peer0.blockchain.xinwang.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain.xinwang.com/users/Admin@blockchain.xinwang.com/msp
		if [ $1 -eq 2 ]; then
			CORE_PEER_ADDRESS=peer0.blockchain.xinwang.com:7051
		else
			CORE_PEER_ADDRESS=peer1.blockchain.xinwang.com:7051
		fi
	else
    	CORE_PEER_LOCALMSPID="KeShangMSP"
        CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain.keshang.com/peers/peer0.blockchain.keshang.com/tls/ca.crt
        CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain.keshang.com/users/Admin@blockchain.keshang.com/msp
        if [ $1 -eq 4 ]; then
            CORE_PEER_ADDRESS=peer0.blockchain.keshang.com:7051
        else
            CORE_PEER_ADDRESS=peer1.blockchain.keshang.com:7051
        fi

	fi

	env |grep CORE
}

createChannel() {
	setGlobals 0

    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer.belink.com:7050 -t $TIMEOUT -c $CHANNEL_NAME -f ./channel-artifacts/$CHANNEL_NAME.tx >&log.txt
	else
		peer channel create -o orderer.belink.com:7050 -t $TIMEOUT -c $CHANNEL_NAME -f ./channel-artifacts/$CHANNEL_NAME.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

updateAnchorPeers() {
    PEER=$1
    setGlobals $PEER

    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update -o orderer.belink.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	else
		peer channel update -o orderer.belink.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	sleep $DELAY
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep $DELAY
		joinWithRetry $1
	else
		COUNTER=1
	fi
    verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	ch=$1
	setGlobals $ch
	joinWithRetry $ch
	echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
	sleep $DELAY
	echo
}

installChaincode () {
	PEER=$1
	chaincodeName=$2
	chaincodePath=$3
	setGlobals $PEER
	peer chaincode install -n $chaincodeName -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/$chaincodePath >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}


instantiateChaincode () {
	PEER=$1
	chaincodeName=$2
	chaincodePath=$3
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer.belink.com:7050 -C $CHANNEL_NAME -n $chaincodeName -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "AND ('BelinkMSP.member')" >&log.txt
	else
		peer chaincode instantiate -o orderer.belink.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $chaincodeName -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "AND ('BelinkMSP.member')" >&log.txt
        fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

chaincodeQuery () {
  PEER=$1
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep $DELAY
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n loandetail -c '{"Args":["query", "TTTLRR03", ""]}' >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     test "$VALUE" = "$2" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
	exit 1
  fi
}

chaincodeInvoke () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.belink.com:7050 -C $CHANNEL_NAME -n loandetail -c '{"accountState":"4","borrowerType":"07","contractNo":"TTTLRR03","customerName":"好着急","customerNo":"0000001000084653","debitInterestAmount":0.00,"delayBalance":0.00,"firstPayDate":"2017/06/08","guaranteeMethod":"4","loanAmount":1404.80,"loanDate":"2017/06/08","loanEndDate":"2018/05/08","loanNumber":"20170607171137835606929584404492","loanPurpose":"9","loanType":"03","maxDelayDays":0,"normalBalance":1404.80,"payMethod":"02","penaltyAmount":0.00,"penaltyRate":0.0002667,"periods":12,"productName":"好人贷-ML - 车款分期","productNo":"F021009002008001","rate":0.00017780,"rateType":"01","receiverBankNo":"9010002010000290","receiverBankType":"新网银行","receiverName":"好着急","repaidPeriod":0,"repaymentPeriod":"0","settleOnDate":"","stopInterestFlag":"0","transactionDate":"2017/06/08","transactionFlowNo":"0"}' >&log.txt
	else
		peer chaincode invoke -o orderer.belink.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n loandetail -c '{"accountState":"4","borrowerType":"07","contractNo":"TTTLRR03","customerName":"好着急","customerNo":"0000001000084653","debitInterestAmount":0.00,"delayBalance":0.00,"firstPayDate":"2017/06/08","guaranteeMethod":"4","loanAmount":1404.80,"loanDate":"2017/06/08","loanEndDate":"2018/05/08","loanNumber":"20170607171137835606929584404492","loanPurpose":"9","loanType":"03","maxDelayDays":0,"normalBalance":1404.80,"payMethod":"02","penaltyAmount":0.00,"penaltyRate":0.0002667,"periods":12,"productName":"好人贷-ML - 车款分期","productNo":"F021009002008001","rate":0.00017780,"rateType":"01","receiverBankNo":"9010002010000290","receiverBankType":"新网银行","receiverName":"好着急","repaidPeriod":0,"repaymentPeriod":"0","settleOnDate":"","stopInterestFlag":"0","transactionDate":"2017/06/08","transactionFlowNo":"0"}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

# fetchChannelConfig <channel_id> <output_json>
# Writes the current channel config for a given channel to a JSON file
fetchChannelConfig() {
  CHANNEL=$1
  OUTPUT=$2

  setOrdererGlobals

  echo "Fetching the most recent configuration block for the channel"
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer channel fetch config config_block.pb -o orderer.belink.com:7050 -c $CHANNEL --cafile $ORDERER_CA
    set +x
  else
    set -x
    peer channel fetch config config_block.pb -o orderer.belink.com:7050 -c $CHANNEL --tls --cafile $ORDERER_CA
    set +x
  fi

  echo "Decoding config block to JSON and isolating config to ${OUTPUT}"
  set -x
  configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > "${OUTPUT}"
  set +x
}

createConfigUpdate() {
  CHANNEL=$1
  ORIGINAL=$2
  MODIFIED=$3
  OUTPUT=$4

  set -x
  configtxlator proto_encode --input "${ORIGINAL}" --type common.Config > original_config.pb
  configtxlator proto_encode --input "${MODIFIED}" --type common.Config > modified_config.pb
  configtxlator compute_update --channel_id "${CHANNEL}" --original original_config.pb --updated modified_config.pb > config_update.pb
  configtxlator proto_decode --input config_update.pb  --type common.ConfigUpdate > config_update.json
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
  configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope > "${OUTPUT}"
  set +x
}

# signConfigtxAsPeerOrg <org> <configtx.pb>
# Set the peerOrg admin of an org and signing the config update
signConfigtxAsPeerOrg() {
        PEER=$1
        TX=$2
        setGlobals $PEER
        set -x
        peer channel signconfigtx -f "${TX}"
        set +x
}


sleep 40

CHANNEL_NAME="xinwangchannel"
## Create channel
echo "Creating channel $CHANNEL_NAME..."
createChannel
### Fetch channel config
echo "fetch channel config from orderer..."
fetchChannelConfig ${CHANNEL_NAME} ${CHANNEL_NAME}_config.json
#
### Join the peers to the channel
echo "Having all peers join the channel..."
joinChannel 0
joinChannel 1
#
declare -a arr=("chaincode_example02")
for i in "${arr[@]}"
do
    ## Install chaincode on Peer0/Org1 and Peer2/Org2
    echo "Installing chaincode on org1/peer0..."
    installChaincode 0 ${i} $i
    echo "Installing chaincode on org1/peer1..."
    installChaincode 1 ${i} $i
    ## Instantiate chaincode on Peer2/Org2
    echo "Instantiating chaincode on org2/peer2..."
    instantiateChaincode 0 ${i} $i
   # or do whatever with individual element of the array
done
#
echo "Installing jq"
apt-get -y update && apt-get -y install jq
#
### Fetch channel config
echo "fetch channel config from orderer..."
fetchChannelConfig ${CHANNEL_NAME} ${CHANNEL_NAME}_config.json
#
# Modify the configuration to append the new org
set -x
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"XinWangMSP":.[1]}}}}}' ${CHANNEL_NAME}_config.json ./channel-artifacts/${CHANNEL_NAME}.json > ${CHANNEL_NAME}_modified_config.json
set +x
#
# Compute a config update, based on the differences between config.json and modified_config.json, write it as a transaction to org3_update_in_envelope.pb
createConfigUpdate ${CHANNEL_NAME} ${CHANNEL_NAME}_config.json ${CHANNEL_NAME}_modified_config.json ${CHANNEL_NAME}_update_in_envelope.pb
#
#echo "Signing config transaction"
#signConfigtxAsPeerOrg 0 config_update_in_envelope.pb
#
echo
echo "========= Submitting transaction from a different peer (peer0.org1) which also signs it ========= "
echo
setGlobals 0
set -x
peer channel update -f ${CHANNEL_NAME}_update_in_envelope.pb -c ${CHANNEL_NAME} -o orderer.belink.com:7050 --tls --cafile ${ORDERER_CA}
set +x
#
#peer channel fetch 0 $CHANNEL_NAME.block -o orderer.belink.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
#
joinChannel 2
#
installChaincode 2 "chaincode_example02" "chaincode_example02"


#CHANNEL_NAME="keshangchannel"
## Create channel
#echo "Creating channel $CHANNEL_NAME..."
#createChannel
#
### Join the peers to the channel
#echo "Having all peers join the channel..."
#joinChannel 0
#joinChannel 1
#
#declare -a arr=("chaincode_example02")
#for i in "${arr[@]}"
#do
    ## Install chaincode on Peer0/Org1 and Peer2/Org2
#    echo "Installing chaincode on org1/peer0..."
#    installChaincode 0 ${i} $i
#    echo "Installing chaincode on org1/peer1..."
#    installChaincode 1 ${i} $i
    ## Instantiate chaincode on Peer2/Org2
#    echo "Instantiating chaincode on org2/peer2..."
#    instantiateChaincode 0 ${i} $i
   # or do whatever with individual element of the array
#done
#
### Fetch channel config
#echo "fetch channel config from orderer..."
#fetchChannelConfig ${CHANNEL_NAME} config.json


##Query on chaincode on Peer0/Org1
#echo "Querying chaincode on org1/peer0..."
#chaincodeQuery 0 100
#
##Invoke on chaincode on Peer0/Org1
#echo "Sending invoke transaction on org1/peer0..."
#chaincodeInvoke 0
#
##Query on chaincode on Peer3/Org2, check if the result is 90
#echo "Querying chaincode on org2/peer3..."
#chaincodeQuery 3 90

updateChaincode () {
    PEER=$1
	setGlobals $PEER
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
        peer chaincode upgrade -o orderer.belink.com:7050  -C $CHANNEL_NAME -n payplan -v 2.0 -c '{"Args":["init","a","100","b","200"]}' -P "AND	('BelinkMSP.member','XinWangMSP.member')"
    else
        peer chaincode upgrade -o orderer.belink.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n payplan -v 2.0 -c '{"Args":["init","a","100","b","200"]}' -P "AND	('BelinkMSP.member','XinWangMSP.member')"
    fi
}

installUpdateChaincode () {
	PEER=$1
	chaincodeName=$2
	chaincodePath=$3
	setGlobals $PEER
	peer chaincode install -n $chaincodeName -v 2.0 -p github.com/hyperledger/fabric/examples/chaincode/go/$chaincodePath >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}

#installUpdateChaincode 0 payplan payplan
#
#installUpdateChaincode 1 payplan payplan
#
#installUpdateChaincode 2 payplan payplan
#
#installUpdateChaincode 3 payplan payplan
#
#updateChaincode 0

echo
echo "========= All GOOD, BYFN execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0



