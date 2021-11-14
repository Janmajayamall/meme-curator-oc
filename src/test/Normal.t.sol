// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "./../OracleMarkets.sol";

contract Normal is DSTest {

    function setUp() public {

    }

    function createOracle() public {
        address oracle = address(new OracleMarkets(address(this)));
        OracleMarkets(oracle).updateCollateralToken(address(this));
        OracleMarkets(oracle).updateMarketConfig(true, 10, 100, 10, 10, 100, 100);
    }
}