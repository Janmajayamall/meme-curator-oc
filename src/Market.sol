// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './OutcomeToken.sol';
import './interfaces/IMarketFactory.sol';
import './interfaces/IMarket.sol';
import './interfaces/IModerationCommitee.sol';
import './interfaces/IOutcomeToken.sol';
import './interfaces/IERC20.sol';

contract Market is IMarket {
    uint256 reserve0;
    uint256 reserve1;
    uint256 reserveC;
    
    address immutable token0;
    address immutable token1;
    address immutable tokenC;

    address immutable creator;
    address immutable oracle;

    /* 
    Staking Info
    */
    uint256 reserveDoN0;
    uint256 reserveDoN1;
    Staking staking;
    // bytes32 (i.e. keccak(en(address,key))) => amount staked
    mapping(bytes32 => uint256) stakes;

    MarketDetails marketDetails;
    string identifier;

    constructor(){
        address _oracle;
        (creator, _oracle, identifier) = IMarketFactory(msg.sender).deployParams();

        // retrieve market configurtion from oracle
        MarketDetails memory _details;
        bool isActive;
        (tokenC, isActive, _details.oracleFeeNumerator, _details.oracleFeeDenominator, _details.donEscalationLimit, _details.expireBufferBlocks, _details.donBufferBlocks, _details.resolutionBufferBlocks) = IModerationCommitte(_oracle).getMarketParams();
        require(isActive == true);
        require(_details.oracleFeeNumerator <= _details.oracleFeeDenominator);
        _details.outcome = 2;
        marketDetails = _details;
        oracle = _oracle;
        token0 = address(new OutcomeToken()); // significant gas cost
        token1 = address(new OutcomeToken());
    }

    function totalReservesTokenC() internal view returns (uint reserves){
        reserves = reserveC+reserveDoN0+reserveDoN1;
    }

    function isMarketFunded() internal view returns (bool) {
        MarketDetails memory _details = marketDetails;
        if (_details.stage == uint8(Stages.MarketFunded) && block.number < _details.expireAtBlock) return true;
        return false;
    }

    function isMarketClosed() internal returns (bool, uint8){
        MarketDetails memory _details = marketDetails;    
        if (_details.stage != uint8(Stages.MarketClosed) && _details.stage != uint8(Stages.MarketCreated)){
            if(
                (_details.stage != uint8(Stages.MarketResolve) && block.number >= _details.donBufferEndsAtBlock && (_details.donBufferBlocks == 0 || _details.donEscalationLimit != 0))
                || (block.number >=  _details.resolutionEndsAtBlock && (_details.stage == uint8(Stages.MarketResolve) || _details.donEscalationLimit == 0))
                )
            {
                // Set outcome by expiry  
                Staking memory _staking = staking;
                if (_staking.staker0 == address(0) && _staking.staker1 == address(0)){
                    uint _reserve0 = reserve0;
                    uint _reserve1 = reserve1;
                    if (_reserve0 < _reserve1){
                        _details.outcome = 0;
                    }else if (_reserve1 < _reserve0){
                        _details.outcome = 1;
                    }else {
                        _details.outcome = 2;
                    }
                }else{
                    _details.outcome = _staking.lastOutcomeStaked;
                }
                _details.stage = uint8(Stages.MarketClosed);
                marketDetails = _details;
                return (true, _details.outcome); 
            }
           return (false, 2);
        }
        return (true, _details.outcome);
    }

    function getMarketInfo() external override view returns(string memory, address, address){
        return (identifier,creator,oracle);
    }

    // get token addresses
    function getTokenAddresses() external override view returns (address,address,address){
        return (tokenC, token0, token1);
    }

    function getOutcomeReserves() external override view returns (uint,uint){
        return (reserve0, reserve1);
    }

    function getTokenCReserves() external override view returns (uint,uint,uint){
        return (reserveC, reserveDoN0, reserveDoN1);
    }

    // get market details
    function getMarketDetails() external override view returns (
        uint[12] memory detailsArr
    ) {
        MarketDetails memory _details = marketDetails;
        detailsArr[0] = _details.expireAtBlock;
        detailsArr[1] = _details.donBufferEndsAtBlock;
        detailsArr[2] = _details.resolutionEndsAtBlock;
        detailsArr[3] = _details.expireBufferBlocks;
        detailsArr[4] = _details.donBufferBlocks;
        detailsArr[5] = _details.resolutionBufferBlocks;
        detailsArr[6] = _details.donEscalationCount;
        detailsArr[7] = _details.donEscalationLimit;
        detailsArr[8] = _details.oracleFeeNumerator;
        detailsArr[9] = _details.oracleFeeDenominator;
        detailsArr[10] = _details.outcome;
        detailsArr[11] = _details.stage;
    }

    // get staking info
    function getStaking() external override view returns(uint,address,address,uint8){
        Staking memory _staking = staking;
        return (
            _staking.lastAmountStaked,
            _staking.staker0,
            _staking.staker1,
            _staking.lastOutcomeStaked
        );
    }

    // get stake
    function getStake(uint _for, address _of) external override view returns(uint){
        return stakes[keccak256(abi.encode(_of, _for))];
    }

    function fund() external override {
        MarketDetails memory _details = marketDetails;
        require(_details.stage == uint8(Stages.MarketCreated));

        uint amount = IERC20(tokenC).balanceOf(address(this)); // tokenC reserve is 0 at this point
        
        IOutcomeToken(token0).issue(address(this), amount);
        IOutcomeToken(token1).issue(address(this), amount);   

        reserve0 += amount;
        reserve1 += amount;
        reserveC += amount;

        _details.stage = uint8(Stages.MarketFunded);
        _details.expireAtBlock = uint32(block.number) + _details.expireBufferBlocks;
        _details.donBufferEndsAtBlock = _details.expireAtBlock + _details.donBufferBlocks; // pre-set buffer expiry for first buffer period
        _details.resolutionEndsAtBlock = _details.expireAtBlock + _details.resolutionBufferBlocks; // pre-set resolution expiry, in case donEscalationLimit == 0 && donBufferBlocks > 0
        marketDetails = _details;
        
        require(amount > 0, 'ZERO');
    }
    
    function buy(uint amount0, uint amount1, address to) external override {
        require(isMarketFunded());

        address _token0 = token0;
        address _token1 = token1;
        uint _reserve0 = reserve0;
        uint _reserve1 = reserve1;

        uint reserveTokenC = totalReservesTokenC();
        uint balance = IERC20(tokenC).balanceOf(address(this));
        uint amount = balance - reserveTokenC;

        // buying all tokens
        IOutcomeToken(_token0).issue(address(this), amount);
        IOutcomeToken(_token1).issue(address(this), amount);

        // transfer
        if (amount0 > 0) IOutcomeToken(_token0).transfer(to, amount0);
        if (amount1 > 0) IOutcomeToken(_token1).transfer(to, amount1);

        uint _reserve0New = (_reserve0 + amount) - amount0;
        uint _reserve1New = (_reserve1 + amount) - amount1;
        require((_reserve0*_reserve1) <= (_reserve0New*_reserve1New), "ERR - INV");

        reserve0 = _reserve0New;
        reserve1 = _reserve1New;
        reserveC += amount;

        emit OutcomeTraded(address(this), to);
    }   

    function sell(uint amount, address to) external override {
        require(isMarketFunded());

        address _tokenC = tokenC;
        uint _reserve0 = reserve0;
        uint _reserve1 = reserve1;

        IERC20(_tokenC).transfer(to, amount);

        uint balance0 = IOutcomeToken(token0).balanceOf(address(this));
        uint balance1 = IOutcomeToken(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        // burn outcome tokens
        IOutcomeToken(token0).transfer(address(0), amount);
        IOutcomeToken(token1).transfer(address(0), amount);

        uint _reserve0New = (_reserve0 + amount0) - amount;
        uint _reserve1New = (_reserve1 + amount1) - amount;
        require((_reserve0*_reserve1) <= (_reserve0New*_reserve1New), "ERR - INV");

        reserve0 = _reserve0New;
        reserve1 = _reserve1New;
        reserveC -= amount;

        emit OutcomeTraded(address(this), to);
    }

    function redeemWinning(uint _for, address to) external override {
        (bool valid, uint8 outcome) = isMarketClosed();
        require(valid);

        uint amount;
        if (_for == 0){
            address _token0 = token0;
            uint balance = IOutcomeToken(_token0).balanceOf(address(this));
            amount = balance - reserve0;
            IOutcomeToken(_token0).transfer(address(0), amount);
        }else if (_for == 1){
            address _token1 = token1;
            uint balance = IOutcomeToken(_token1).balanceOf(address(this));
            amount = balance - reserve1;
            IOutcomeToken(_token1).transfer(address(0), amount);
        }

        if (outcome == 2){
            amount = amount/2;                
        }else if (outcome != _for){
            amount = 0;
        }
        IERC20(tokenC).transfer(to, amount);

        reserveC -= amount;

        require(_for < 2);

        emit WinningRedeemed(address(this), to);
    }

    function stakeOutcome(uint _for, address to) external override {
        MarketDetails memory _details = marketDetails;
        if (_details.stage == uint8(Stages.MarketFunded) && block.number >= _details.expireAtBlock){
            _details.stage = uint8(Stages.MarketBuffer);
        }
        require(
            _details.stage == uint8(Stages.MarketBuffer) 
            && _details.donEscalationCount < _details.donEscalationLimit
            && block.number < _details.donBufferEndsAtBlock
        );

        require(_for < 2);

        uint reserveTokenC = totalReservesTokenC();
        uint balance = IERC20(tokenC).balanceOf(address(this));
        uint amount = balance - reserveTokenC;

        Staking memory _staking = staking;

        bytes32 key = keccak256(abi.encode(to, _for));
        stakes[key] += amount;
        if (_for == 0) {
            reserveDoN0 += amount;
            _staking.staker0 = to;
            _staking.lastOutcomeStaked = 0;
        }
        if (_for == 1) {
            reserveDoN1 += amount;
            _staking.staker1 = to;
            _staking.lastOutcomeStaked = 1;
        } 

        require(amount != 0, "ZERO");
        require(amount >= (_staking.lastAmountStaked * 2), "DBL");
        _staking.lastAmountStaked = amount;
        staking = _staking;

        if (_details.donEscalationCount + 1 < _details.donEscalationLimit){
            _details.donBufferEndsAtBlock = uint32(block.number) + _details.donBufferBlocks;
        }else{
            _details.resolutionEndsAtBlock = uint32(block.number) + _details.resolutionBufferBlocks;
            _details.stage = uint8(Stages.MarketResolve);
        }
        _details.donEscalationCount += 1;
        marketDetails = _details;

        emit OutcomeStaked(address(this), to);
    }

    function redeemStake(uint _for) external override {
        require(_for < 2);

        (bool valid, uint8 outcome) = isMarketClosed();
        require(valid);
        
        uint _reserveDoN0 = reserveDoN0;
        uint _reserveDoN1 = reserveDoN1;

        bytes32 key = keccak256(abi.encode(msg.sender, _for));
        uint amount = stakes[key];
        stakes[key] = 0;

        if (outcome == 2){    
            if (_for == 0) _reserveDoN0 -= amount;
            if (_for == 1) _reserveDoN1 -= amount;
        }else if (outcome == _for){
            Staking memory _staking = staking;
            if (outcome == 0) {
                _reserveDoN0 -= amount;
                if (_staking.staker0 == msg.sender || _staking.staker0 == address(0)){
                    amount += _reserveDoN1;
                    _reserveDoN1 = 0;
                }
            }else if (outcome == 1) {
                _reserveDoN1 -= amount;
                if (_staking.staker1 == msg.sender || _staking.staker1 == address(0)){
                    amount += _reserveDoN0;
                    _reserveDoN0 = 0;
                }
            }
        }else {
            amount = 0;
        }

        IERC20(tokenC).transfer(msg.sender, amount);

        reserveDoN0 = _reserveDoN0;
        reserveDoN1 = _reserveDoN1;

        emit StakedRedeemed(address(this), msg.sender);
    }

    function setOutcome(uint8 outcome) external override {
        require(outcome < 3);
        
        MarketDetails memory _details = marketDetails;
        if (_details.stage == uint8(Stages.MarketFunded) 
            && _details.donEscalationLimit == 0
            && _details.donBufferBlocks != 0){
            // donEscalationLimit == 0, indicates direct transition to MarketResolve after Market expiry
            // But if donBufferPeriod == 0 as well, then transition to MarketClosed after Market expiry
            _details.stage = uint8(Stages.MarketResolve);
        }
        require(_details.stage == uint8(Stages.MarketResolve) && block.number < _details.resolutionEndsAtBlock);
        
        address _oracle = oracle;
        require(msg.sender == _oracle);
    
        uint oracleFeeNumerator = _details.oracleFeeNumerator;
        uint oracleFeeDenominator = _details.oracleFeeDenominator;

        uint fee;
        if (outcome != 2 && oracleFeeNumerator != 0){
            uint _reserveDoN1 = reserveDoN1;
            uint _reserveDoN0 = reserveDoN0;
            if (outcome == 0 && _reserveDoN1 != 0) {
                fee = (_reserveDoN1*oracleFeeNumerator)/oracleFeeDenominator;
                reserveDoN1 -= fee;
            }
            if (outcome == 1 && _reserveDoN0 != 0) {
                fee = (_reserveDoN0*oracleFeeNumerator)/oracleFeeDenominator;
                reserveDoN0 -= fee;
            }
        }
        
        _details.outcome = outcome;
        _details.stage = uint8(Stages.MarketClosed);
        marketDetails = _details;

        IERC20(tokenC).transfer(_oracle, fee);

        emit OutcomeSet(address(this));
    }

    function claimReserve() external override { 
        (bool valid,) = isMarketClosed();
        require(valid);
        address _creator = creator;
        require(msg.sender == _creator);
        IOutcomeToken(token0).transfer(_creator, reserve0);
        IOutcomeToken(token1).transfer(_creator, reserve1);
        reserve0 = 0;
        reserve1 = 0;
    }
}
