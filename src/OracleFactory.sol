// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './OracleSingle.sol';
import './interfaces/IModerationCommitee.sol';

contract OracleFactory {

    event OracleRegistered(address indexed oracle);

    function setupSingleOracle(
        address delegate,
        address _tokenC, 
        bool _isActive, 
        uint8 _feeNumerator, 
        uint8 _feeDenominator,
        uint16 _donEscalationLimit, 
        uint32 _expireBufferBlocks, 
        uint32 _donBufferBlocks, 
        uint32 _resolutionBufferBlocks
    ) external {
        address oracle = address(new OracleSingle(
            delegate,
            _tokenC, 
            _isActive, 
            _feeNumerator, 
            _feeDenominator,
            _donEscalationLimit, 
            _expireBufferBlocks, 
            _donBufferBlocks, 
            _resolutionBufferBlocks
        ));
        emit OracleRegistered(oracle);
    }

    function updateOracle(
        address _tokenC, 
        bool _isActive, 
        uint8 _feeNumerator, 
        uint8 _feeDenominator,
        uint16 _donEscalationLimit, 
        uint32 _expireBufferBlocks, 
        uint32 _donBufferBlocks, 
        uint32 _resolutionBufferBlocks,
        address oracleAddress
    ) external {
        (bool success,) = oracleAddress.call(abi.encodeWithSignature("updateParams(address,bool,uint8,uint8,uint16,uint32,uint32,uint32)",
            _tokenC, 
            _isActive, 
            _feeNumerator, 
            _feeDenominator,
            _donEscalationLimit, 
            _expireBufferBlocks, 
            _donBufferBlocks, 
            _resolutionBufferBlocks,
            oracleAddress
            )
        );
        require(success);
        emit OracleRegistered(oracleAddress);
    }

    function registerOracle(address oracle) external {
        address delegate = IModerationCommitte(oracle).getDelegate();
        require(delegate != address(0));

        IModerationCommitte(oracle).getMarketParams();
        emit OracleRegistered(oracle);
    }

}