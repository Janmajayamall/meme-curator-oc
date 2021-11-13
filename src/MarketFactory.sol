// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './Market.sol';
import './interfaces/IMarketFactory.sol';
import './interfaces/IMarket.sol';
import './libraries/TransferHelper.sol';

contract MarketFactory is IMarketFactory {

    struct DeployParams {
        address creator;
        address oracle;
        string identifier;
    }

    DeployParams public override deployParams;

    event MarketCreated(address indexed market);

    function createMarket(address _creator, address _oracle, string memory _identifier) override external returns (address marketAddress){
        deployParams = DeployParams({creator: _creator, oracle: _oracle, identifier: _identifier});
        marketAddress = address(new Market{salt: keccak256(abi.encode(_creator, _oracle, _identifier))}());
        delete deployParams;
        emit MarketCreated(marketAddress);
    }
}