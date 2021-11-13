pragma solidity ^0.8.0;

import './../Market.sol';

contract ContractHelper {
    function getMarketContractInitBytecodeHash() external pure returns (bytes32 initHash){
        bytes memory initCode = type(Market).creationCode;
        initHash = keccak256(initCode);
    }
}