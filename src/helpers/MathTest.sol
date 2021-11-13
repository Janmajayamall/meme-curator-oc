// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './../libraries/Math.sol';

contract MathTest {

    uint public reserve0;
    uint public reserve1;

    uint public balance0;
    uint public balance1;

    function fund(uint amount) external {
        reserve0 += amount;
        reserve1 += amount;
    }


    function buy(uint a0, uint a1, uint a) external {

        require(
            (reserve0 * reserve1) <= (reserve0 + a - a0) * (reserve1 + a - a1), 
            "INVALID INPUTS"
        );
        reserve0 = reserve0 + a - a0;
        reserve1 = reserve1 + a - a1;
        balance0 += a0;
        balance1 += a1;
    }

    function sell(uint a0, uint a1, uint a) external {
        require(
            (reserve0 * reserve1) <= (reserve0 + a0 - a) * (reserve1 + a1 - a),
            "INVALID INPUTS"
        );
        reserve0 = reserve0 + a0 - a;
        reserve1 = reserve1 + a1 - a;
    }

    function getReserves() external view returns (uint, uint){
        return (reserve0, reserve1);
    }

    function getBalances() external view returns (uint, uint){
        return (balance0, balance1);
    }

    function getAmountCToBuyTokens(uint a0, uint a1, uint r0, uint r1) external pure returns (uint) {
        uint amount = Math.getAmountCToBuyTokens(a0, a1, r0, r1);
        return amount;
    }

    function getTokenAmountToBuyWithAmountC(uint fixedTokenAmount, uint fixedTokenIndex, uint r0, uint r1, uint a) external pure returns (uint){
        uint amount = Math.getTokenAmountToBuyWithAmountC(fixedTokenAmount, fixedTokenIndex, r0, r1, a);
        return amount;
    }

    function getAmountCBySellTokens(uint a0, uint a1, uint r0, uint r1) external pure returns (uint){
        uint amount = Math.getAmountCBySellTokens(a0, a1, r0, r1);
        return amount;
    }

    function getTokenAmountToSellForAmountC(uint fixedTokenAmount, uint fixedTokenIndex, uint r0, uint r1, uint a) external pure returns (uint){
        uint amount = Math.getTokenAmountToSellForAmountC(fixedTokenAmount, fixedTokenIndex, r0, r1, a);
        return amount;
    }


}