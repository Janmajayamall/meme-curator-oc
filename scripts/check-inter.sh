#!/usr/bin/env bash

dapp build

DIRECTORY=.
sh $DIRECTORY/scripts/contract-size-main.sh