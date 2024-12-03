#!/bin/bash

###########################################
# Ⓒ Katyatu @ https://github.com/Katyatu #
###########################################

##############################
# Don't Touch Anything!!!    #
#                            #
# A bad edit can result in   #
# loss of funds or crypto!   #
##############################

workdir=$(dirname "$(realpath $0)")
cd $workdir

# Immediate halt if prior insufficient funds event
# has not been manually addressed by user.
if [ -f "$workdir/NOFUNDS" ]; then
  exit
fi

#-----------------------------

# Variables

config=$(cat $workdir/config.json)
buyamount=$(echo $config | jq .buyamount)
testing=$(echo $config | jq .testing)
crypto=$(echo $config | jq .crypto | tr -d '"' | tr 'a-z' 'A-Z')
fiat=$(echo $config | jq .fiat | tr -d '"' | tr 'a-z' 'A-Z')
pair=$crypto$fiat

LBLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

#-----------------------------

if [ "$testing" = true ]; then
  printf "${RED}!!! TESTING MODE IS ACTIVE !!! EXAMPLE DATA USED !!! NO ORDERS ARE PLACED !!!${NC}\n"
fi

# Get account balance.

balresp=$(/usr/bin/nodejs $workdir/krakenapi.js Balance)
balerr=$(echo $balresp | jq .error[])

if [[ ! -z "$balerr" ]] ; then
  printf "${RED}Something went wrong... ${YELLOW}$balerr\n"
  exit
fi

rawbal=$(echo $balresp | jq '.result.Z'$(echo $fiat) | tr -d '"')
bal=${rawbal%.*}

#-----------------------------

if [[ bal -ge $buyamount ]] ; then

  # If balance > buyamount, initiate buy.

  printf "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] Balance: $bal $fiat | Buy Amount: $buyamount $fiat | Sufficient Funds | Executing...\n"
  
  buyresp=$(/usr/bin/nodejs $workdir/krakenapi.js AddOrder pair="$pair" type=buy ordertype=market volume=$buyamount oflags=viqc,fcib validate=$testing)
  buyerr=$(echo $buyresp | jq .error[])

  if [[ ! -z "$buyerr" ]] ; then
    printf "${RED}Something went wrong... ${YELLOW}$buyerr\n"
    exit
  fi

  #-----------------------------

  if [ "$testing" = true ]; then

    # Testing returns the above buy order validation api response for
    # manual confirmation of the specified buy order before going live.
    # Since validate=true, a required TXID is not returned, so example
    # data is used to demonstrate what happens during a live buy order. 
  
    printf "${NC} > $buyresp\n${RED} > Make sure the above api's buy order response is what you want executed.\n > Adjust config vars if needed, live buy orders are irreversible!\n > A successful live buy order will output a result like this:\n${NC}"
    
    buyresp=$(cat $workdir/example/buyresp.json)
  
    txid=$(echo $buyresp | jq .result.txid[] | tr -d '"')
  
    txinfo=$(cat $workdir/example/txinfo.json)
  
  else

    # A successful live buy order returns a TXID
    # which is used for fetching details to form
    # a pretty outout for personal record keeping.

    txid=$(echo $buyresp | jq .result.txid[] | tr -d '"')
  
    txinfo=$(/usr/bin/nodejs $workdir/krakenapi.js QueryOrders txid="$txid")

  fi

  #-----------------------------

  # With all needed data collected, a clean final output is printed to console.

  txprice=$(echo $txinfo | jq '.result."'"$txid"'".price' | tr -d '"')
  txcost=$(echo $txinfo | jq '.result."'"$txid"'".cost' | tr -d '"')
  txfee=$(echo $txinfo | jq '.result."'"$txid"'".fee' | tr -d '"')
  txvol=$(echo $txinfo | jq '.result."'"$txid"'".vol_exec' | tr -d '"')

  printf "${YELLOW}[$txid] Exchanged $txcost $fiat for $txvol $crypto @ $txprice $fiat / 1 $crypto (Fee: $txfee $fiat)\n${NC}"

#-----------------------------
  
# If balance < buyamount, halt automation and require manual intervention.

else

  printf "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] Balance: $bal $fiat | Buy Amount: $buyamount $fiat | Insufficient funds | Stopping...\nTo restart automation, re-fund your account, then delete "$workdir"/NOFUNDS.\nThe next scheduled crontab iteration will proceed as normal.${NC}\n"
  touch "$workdir/NOFUNDS"
  
fi

#-----------------------------

printf "${LBLUE}\n-._,-\'\"\`-._,-\'\"\`-._,-\'\"\`-._,-\'\"\`-._,-\'-._,-\'\"\`-._,-\'\"\`-._,-\'\"\`-._,-\'\"\`-._,-\'\"\`-._,-\'\"\`-._,-\'\"\`-${NC}\n\n"
