// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './interfaces/IModerationCommitee.sol';

contract OracleSingle is IModerationCommitte {

    MarketConfig public marketConfig;
    address delegate;

    constructor(
            address _delegate,
            address _tokenC, 
            bool _isActive, 
            uint8 _feeNumerator, 
            uint8 _feeDenominator,
            uint16 _donEscalationLimit, 
            uint32 _expireBufferBlocks, 
            uint32 _donBufferBlocks, 
            uint32 _resolutionBufferBlocks
            ) {
        delegate = _delegate;
        _setupOracle(_tokenC, _isActive, _feeNumerator, _feeDenominator, _donEscalationLimit, _expireBufferBlocks, _donBufferBlocks, _resolutionBufferBlocks);
    }

    modifier onlyDelegate() {
        require(msg.sender == delegate);
        _;
    }

    function _setupOracle(
        address _tokenC, 
        bool _isActive, 
        uint8 _feeNumerator, 
        uint8 _feeDenominator,
        uint16 _donEscalationLimit, 
        uint32 _expireBufferBlocks, 
        uint32 _donBufferBlocks, 
        uint32 _resolutionBufferBlocks
    ) internal {
        MarketConfig memory _config;
        _config.tokenC = _tokenC;
        _config.isActive = _isActive;
        _config.feeNumerator = _feeNumerator;
        _config.feeDenominator = _feeDenominator;
        _config.donEscalationLimit = _donEscalationLimit;
        _config.expireBufferBlocks = _expireBufferBlocks;
        _config.donBufferBlocks = _donBufferBlocks;
        _config.resolutionBufferBlocks = _resolutionBufferBlocks;
        marketConfig = _config;
    }

    function getMarketParams() external view override returns (address,bool,uint8,uint8,uint16,uint32,uint32,uint32){
        MarketConfig memory _config = marketConfig;
        return (
            _config.tokenC,
            _config.isActive,
            _config.feeNumerator,
            _config.feeDenominator,
            _config.donEscalationLimit,
            _config.expireBufferBlocks,
            _config.donBufferBlocks,
            _config.resolutionBufferBlocks
        );
    }

    function getDelegate() external view override returns (address){
        return delegate;
    }

    function updateParams(
            address _tokenC, 
            bool _isActive, 
            uint8 _feeNumerator, 
            uint8 _feeDenominator,
            uint16 _donEscalationLimit, 
            uint32 _expireBufferBlocks, 
            uint32 _donBufferBlocks, 
            uint32 _resolutionBufferBlocks
        ) external onlyDelegate {
        _setupOracle(_tokenC, _isActive, _feeNumerator, _feeDenominator, _donEscalationLimit, _expireBufferBlocks, _donBufferBlocks, _resolutionBufferBlocks);
    }

    function changeDelegate(address _delegate) external onlyDelegate {
        delegate = _delegate;
    }

    function setMarketOutcome(uint8 to, address market) external onlyDelegate {
        require(to < 3);
        (bool success,) = market.call(abi.encodeWithSignature("setOutcome(uint8)", to));
        require(success);
    }
}