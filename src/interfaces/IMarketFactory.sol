// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMarketFactory {
    function createMarket(address _creator, address _oracle, string memory _identifier) external returns (address);
    function deployParams() external returns (address,address,string memory);
}