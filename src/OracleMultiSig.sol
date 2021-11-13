// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './libraries/MultiSigWallet.sol';
import './interfaces/IModerationCommitee.sol';

contract OracleMultiSig is MultiSigWallet, IModerationCommitte {

    MarketConfig public marketConfig;
    address delegate;

    constructor(address[] memory _owners, uint _required, uint maxCount, address _delegate) MultiSigWallet(_owners, _required, maxCount) {
        delegate = _delegate;
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

    function getDelegate() external view override returns (address) {
        return delegate;
    }

    function setupOracle(address _tokenC, bool _isActive, uint8 _feeNumerator, uint8 _feeDenominator,uint16 _donEscalationLimit, uint32 _expireBufferBlocks, uint32 _donBufferBlocks, uint32 _resolutionBufferBlocks) external onlyWallet {
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

    /* 
        In factory always check whether the oracle is active or not
     */

    function changeFee(uint8 _feeNumerator, uint8 _feeDenominator) external onlyWallet {
        require(_feeNumerator <= _feeDenominator);
        MarketConfig memory _config = marketConfig;
        _config.feeNumerator = _feeNumerator;
        _config.feeDenominator = _feeDenominator;
        marketConfig = _config;
    }   

    function changeActive(bool _isActive) external onlyWallet {
        marketConfig.isActive = _isActive;
    }
    
    function changeTokenC(address _tokenC) external onlyWallet {
        marketConfig.tokenC = _tokenC;
    }

    function changeActive(uint32 _expireBufferBlocks) external onlyWallet {
        marketConfig.expireBufferBlocks = _expireBufferBlocks;
    }

    function changeDonEscalationLimit(uint16 _donEscalationLimit) external onlyWallet {
        marketConfig.donEscalationLimit = _donEscalationLimit;
    }

    function changeDonBufferBlocks(uint32 _donBufferBlocks) external onlyWallet {
        marketConfig.donBufferBlocks = _donBufferBlocks;
    }

    function changeResolutionBufferBlocks(uint32 _resolutionBufferBlocks) external onlyWallet {
        marketConfig.resolutionBufferBlocks = _resolutionBufferBlocks;
    }

    function changeDelegate(address _delegate) external onlyWallet {
        delegate = _delegate;
    }

    /* 
    Helper functions for adding txs for functions above
     */
    function addTxSetupOracle(address _tokenC, bool _isActive, uint8 _feeNumerator, uint8 _feeDenominator,uint16 _donEscalationLimit, uint32 _expireBufferBlocks, uint32 _donBufferBlocks, uint32 _resolutionBufferBlocks) external ownerExists(msg.sender)  {
        bytes memory data = abi.encodeWithSignature(
            "setupOracle(address,bool,uint8,uint8,uint16,uint32,uint32,uint32)", 
            _tokenC, _isActive, _feeNumerator, _feeDenominator, _donEscalationLimit, _expireBufferBlocks, _donBufferBlocks, _resolutionBufferBlocks
            );
        submitTransaction(address(this), 0, data);
    }

    function addTxSetMarketOutcome(uint8 to, address market) external ownerExists(msg.sender){
        require(to < 3);
        bytes memory data = abi.encodeWithSignature("setOutcome(uint8)", to);
        submitTransaction(market, 0, data);
    }

    function addTxChangeDonEscalationLimit(uint16 _donEscalationLimit) external ownerExists(msg.sender) {
        bytes memory data = abi.encodeWithSignature(
            "changeDonEscalationLimit(uint16)", 
            _donEscalationLimit
            );
        submitTransaction(address(this), 0, data);
    }

    function addTxChangeDoNBufferBlocks(uint32 _donBufferBlocks) external ownerExists(msg.sender) {
        bytes memory data = abi.encodeWithSignature(
            "changeDonBufferBlocks(uint32)", 
            _donBufferBlocks
            );
        submitTransaction(address(this), 0, data);
    }

    function addTxChangeDelegate(address _delegate) external ownerExists(msg.sender) {
        bytes memory data = abi.encodeWithSignature("changeDelegate(address)", _delegate);
        submitTransaction(address(this), 0, data);
    }
}