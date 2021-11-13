#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

MarketFactory=$(spit_abi MarketFactory "")
MarketRouter=$(spit_abi MarketRouter "" )
OracleMultiSig=$(spit_abi OracleMultiSig "")
MemeToken=$(spit_abi MemeToken "")
ContractHelper=$(spit_abi ContractHelper helpers/)
Market=$(spit_abi Market "")
OracleFactory=$(spit_abi OracleFactory "")
OracleSingle=$(spit_abi OracleSingle "")