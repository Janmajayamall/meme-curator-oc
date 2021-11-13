// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IModerationCommitte {
       struct MarketConfig {
        address tokenC;
        bool isActive;
        uint8 feeNumerator;
        uint8 feeDenominator;
        uint16 donEscalationLimit;
        uint32 expireBufferBlocks;
        uint32 donBufferBlocks;
        uint32 resolutionBufferBlocks;
    }

    function getMarketParams() external view returns (address,bool,uint8,uint8,uint16,uint32,uint32,uint32);    
    function getDelegate() external view returns(address);
}
