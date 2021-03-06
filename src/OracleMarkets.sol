// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './interfaces/IOracleMarkets.sol';
import './interfaces/IERC20.sol';
import './ERC1155.sol';

contract OracleMarkets is ERC1155, IOracleMarkets {
    /*
        marketIdentifier = keccack256(abi.encode(creator, eventIdentifier, address(this)))
    */
    mapping(bytes32 => StateDetails) public stateDetails;
    mapping(bytes32 => Staking) public staking;
    mapping(bytes32 => MarketDetails) public marketDetails;
    mapping(bytes32 => Reserves) public reserves;
    mapping(bytes32 => StakingReserves) public stakingReserves;
    mapping(bytes32 => mapping(bytes32 => uint256)) stakes;
    mapping(bytes32 => address) creators;
    mapping(bytes32 => bytes) eventIdentfiier;

    address public collateralToken;
    MarketConfig public marketConfig;

    address public delegate;

    constructor(address _delegate){
        // setup oracle
        delegate = _delegate;
    }

    function isMarketFunded(bytes32 marketIdentifier) internal view returns (bool) {
        StateDetails memory _details = stateDetails[marketIdentifier];
        if (_details.stage == uint8(Stages.MarketFunded) && block.number < _details.expireAtBlock) return true;
        return false;
    }

    function isMarketClosed(bytes32 marketIdentifier) internal returns (bool, uint8){
        StateDetails memory _stateDetails = stateDetails[marketIdentifier];    
        if (_stateDetails.stage != uint8(Stages.MarketClosed)){
            if(
                _stateDetails.stage != uint8(Stages.MarketCreated) && 
                (
                    (_stateDetails.stage != uint8(Stages.MarketResolve) && block.number >= _stateDetails.donBufferEndsAtBlock && (_stateDetails.donBufferBlocks == 0 || _stateDetails.donEscalationLimit != 0))
                    || (block.number >=  _stateDetails.resolutionEndsAtBlock && (_stateDetails.stage == uint8(Stages.MarketResolve) || _stateDetails.donEscalationLimit == 0))
                )
            )
            {
                // Set outcome by expiry  
                Staking memory _staking = staking[marketIdentifier];
                if (_staking.staker0 == address(0) && _staking.staker1 == address(0)){
                    Reserves memory _reserves = reserves[marketIdentifier];
                    if (_reserves.reserve0 < _reserves.reserve1){
                        _stateDetails.outcome = 0;
                    }else if (_reserves.reserve1 < _reserves.reserve0){
                        _stateDetails.outcome = 1;
                    }else {
                        _stateDetails.outcome = 2;
                    }
                }else{
                    _stateDetails.outcome = _staking.lastOutcomeStaked;
                }
                _stateDetails.stage = uint8(Stages.MarketClosed);
                stateDetails[marketIdentifier] = _stateDetails;
                return (true, _stateDetails.outcome); 
            }
           return (false, 2);
        }
        return (true, _stateDetails.outcome);
    }

    function getOutcomeTokenIds(bytes32 marketIdentifier) public pure returns (uint,uint) {
        return (
            uint256(keccak256(abi.encode(marketIdentifier, 0))),
            uint256(keccak256(abi.encode(marketIdentifier, 1)))
        );
    }
    
    function getReserveTokenIds(bytes32 marketIdentifier) public pure returns (uint,uint){
        return (
            uint256(keccak256(abi.encode('R', marketIdentifier, 0))),
            uint256(keccak256(abi.encode('R', marketIdentifier, 1)))
        );
    }

    function getMarketIdentifier(address _creator, bytes32 _eventIdentifier) public view returns (bytes32 marketIdentifier){
        marketIdentifier = keccak256(abi.encode(_creator, _eventIdentifier, address(this)));
    }

    // function getStateDetails(bytes32 marketIdentifier) external view returns (
    //     uint[9] memory detailsArr
    // ) {
    //     StateDetails memory _details = stateDetails[marketIdentifier];
    //     detailsArr[0] = _details.expireAtBlock;
    //     detailsArr[1] = _details.donBufferEndsAtBlock;
    //     detailsArr[2] = _details.resolutionEndsAtBlock;
    //     detailsArr[3] = _details.donBufferBlocks;
    //     detailsArr[4] = _details.resolutionBufferBlocks;
    //     detailsArr[5] = _details.donEscalationCount;
    //     detailsArr[6] = _details.donEscalationLimit;
    //     detailsArr[7] = _details.outcome;
    //     detailsArr[8] = _details.stage;
    // }

    // // get staking info
    // function getStaking(bytes32 marketIdentifier) external view returns(uint,address,address,uint8){
    //     Staking memory _staking = staking[marketIdentifier];
    //     return (
    //         _staking.lastAmountStaked,
    //         _staking.staker0,
    //         _staking.staker1,
    //         _staking.lastOutcomeStaked
    //     );
    // }

    // function getMarketDetails(bytes32 marketIdentifier) external view returns(address, uint32, uint32) {
    //     MarketDetails memory _marketDetails = marketDetails[marketIdentifier];
    //     return (
    //         _marketDetails.tokenC,
    //         _marketDetails.feeNumerator,
    //         _marketDetails.feeDenominator
    //     );
    // }

    function createAndFundMarket(address _creator, bytes32 _eventIdentifier) external {
        bytes32 marketIdentifier = getMarketIdentifier(_creator, _eventIdentifier);

        require(creators[marketIdentifier] == address(0), 'Market exists');

        address tokenC = collateralToken;

        uint amount = IERC20(tokenC).balanceOf(address(this)); // fundingAmount > 0

        (uint token0Id, uint token1Id) = getOutcomeTokenIds(marketIdentifier);

        // issue outcome tokens
        _mint(address(this), token0Id, amount, '');
        _mint(address(this), token1Id, amount, '');

        // set reserves
        Reserves memory _reserves;
        _reserves.reserve0 = amount;
        _reserves.reserve1 = amount;
        reserves[marketIdentifier] = _reserves; 

        // get market config
        MarketConfig memory _marketConfig = marketConfig;

        // set market details
        MarketDetails memory _marketDetails;
        _marketDetails.tokenC = tokenC;
        _marketDetails.feeNumerator = _marketConfig.feeNumerator;
        _marketDetails.feeDenominator = _marketConfig.feeDenominator;
        marketDetails[marketIdentifier] = _marketDetails;

        // set state details
        StateDetails memory _stateDetails;
        _stateDetails.donBufferBlocks = _marketConfig.donBufferBlocks;
        _stateDetails.resolutionBufferBlocks = _marketConfig.resolutionBufferBlocks;
        _stateDetails.donEscalationLimit = _marketConfig.donEscalationLimit;
        _stateDetails.stage = uint8(Stages.MarketFunded);
        _stateDetails.outcome = 2; // undecided outcome

        _stateDetails.expireAtBlock = uint32(block.number) + _marketConfig.expireBufferBlocks;
        _stateDetails.donBufferEndsAtBlock = _stateDetails.expireAtBlock + _stateDetails.donBufferBlocks; // pre-set buffer expiry for first buffer period
        _stateDetails.resolutionEndsAtBlock = _stateDetails.expireAtBlock + _stateDetails.resolutionBufferBlocks; // pre-set resolution expiry, in case donEscalationLimit == 0 && donBufferBlocks > 0
        stateDetails[marketIdentifier] = _stateDetails;

        // set creator
        creators[marketIdentifier] = _creator;

        require(amount > 0, 'ZERO');

        // oracle is active
        require(marketConfig.isActive, 'Oracle inactive');
    }

    function buy(uint amount0, uint amount1, address to, bytes32 marketIdentifier) external {
        require(isMarketFunded(marketIdentifier));

        // MarketDetails memory _marketDetails = marketDetails;
        Reserves memory _reserves = reserves[marketIdentifier];
        (uint token0Id, uint token1Id) = getOutcomeTokenIds(marketIdentifier);

        uint amount = IERC20(marketDetails[marketIdentifier].tokenC).balanceOf(address(this));

        // buy outcome tokens
        _mint(address(this), token0Id, amount, '');
        _mint(address(this), token1Id, amount, '');

        // transfer outcome tokens
        safeTransferFrom(address(this), to, token0Id, amount0, '');
        safeTransferFrom(address(this), to, token1Id, amount1, '');

        uint _reserve0New = (_reserves.reserve0 + amount) - amount0;
        uint _reserve1New = (_reserves.reserve1 + amount) - amount1;
        require((_reserves.reserve0*_reserves.reserve1) <= (_reserve0New*_reserve1New), "ERR - INV");

        _reserves.reserve0 = _reserve0New;
        _reserves.reserve1 = _reserve1New;

        reserves[marketIdentifier] = _reserves;

        // emit OutcomeTraded(address(this), to);
    } 

    function sell(uint amount, address to, bytes32 marketIdentifier) external {
        require(isMarketFunded(marketIdentifier));

        // MarketDetails memory _marketDetails = marketDetails;
        Reserves memory _reserves = reserves[marketIdentifier];
        (uint token0Id, uint token1Id) = getOutcomeTokenIds(marketIdentifier);

        // transfer optimistically
        IERC20(marketDetails[marketIdentifier].tokenC).transfer(to, amount);

        // check transferred outcome tokens
        uint balance0 = balanceOf(address(this), token0Id);
        uint balance1 = balanceOf(address(this), token1Id);
        uint amount0 = balance0 - _reserves.reserve0;
        uint amount1 = balance1 - _reserves.reserve1;

        // burn outcome tokens
        _burn(address(this), token0Id, amount);
        _burn(address(this), token1Id, amount);

        // update reserves 
        uint _reserve0New = (_reserves.reserve0 + amount0) - amount;
        uint _reserve1New = (_reserves.reserve1 + amount1) - amount;
        require((_reserves.reserve0*_reserves.reserve1) <= (_reserve0New*_reserve1New), "ERR - INV");

        _reserves.reserve0 = _reserve0New;
        _reserves.reserve1 = _reserve1New;
        
        reserves[marketIdentifier] = _reserves;

        // emit OutcomeTraded(address(this), to);
    }

    function stakeOutcome(uint _for, address to, bytes32 marketIdentifier) external {
        StateDetails memory _stateDetails = stateDetails[marketIdentifier];
        if (_stateDetails.stage == uint8(Stages.MarketFunded) && block.number >= _stateDetails.expireAtBlock){
            _stateDetails.stage = uint8(Stages.MarketBuffer);
        }
        require(
            _stateDetails.stage == uint8(Stages.MarketBuffer) 
            && _stateDetails.donEscalationCount < _stateDetails.donEscalationLimit
            && block.number < _stateDetails.donBufferEndsAtBlock
        );

        require(_for < 2);

        uint amount = IERC20(marketDetails[marketIdentifier].tokenC).balanceOf(address(this));
        (uint sToken0Id, uint sToken1Id) = getReserveTokenIds(marketIdentifier);

        StakingReserves memory _stakingReserves = stakingReserves[marketIdentifier];
        Staking memory _staking = staking[marketIdentifier];

        // update staking reserves
        if (_for == 0){
            _mint(to, sToken0Id, amount, '');
            _stakingReserves.reserveS0 += amount;
            _staking.staker0 = to;
            _staking.lastOutcomeStaked = 0;
        }
        if (_for == 1){
            _mint(to, sToken1Id, amount, '');
            _stakingReserves.reserveS1 += amount;
            _staking.staker1 = to;
            _staking.lastOutcomeStaked = 1;
        }

        // update staking info
        require(_staking.lastAmountStaked * 2 <= amount, 'DBL');
        require(amount != 0, 'ZERO');
        _staking.lastAmountStaked = amount;

        stakingReserves[marketIdentifier] = _stakingReserves;
        staking[marketIdentifier] = _staking;
        
        // escalation limit
        if (_stateDetails.donEscalationCount + 1 < _stateDetails.donEscalationLimit){
            _stateDetails.donBufferEndsAtBlock = uint32(block.number) + _stateDetails.donBufferBlocks;
        }else{
            _stateDetails.resolutionEndsAtBlock = uint32(block.number) + _stateDetails.resolutionBufferBlocks;
            _stateDetails.stage = uint8(Stages.MarketResolve);
        }
        _stateDetails.donEscalationCount += 1;
        stateDetails[marketIdentifier] = _stateDetails;

        // emit OutcomeStaked(address(this), to);
    }


    function redeemWinning(address to, bytes32 marketIdentifier) external {
        (bool valid, uint8 outcome) = isMarketClosed(marketIdentifier);
        require(valid);

        Reserves memory _reserves = reserves[marketIdentifier];
        (uint token0Id, uint token1Id) = getOutcomeTokenIds(marketIdentifier);

        // get amount
        uint balance0 = balanceOf(address(this), token0Id);
        uint balance1 = balanceOf(address(this), token1Id);
        uint amount0 = balance0 - _reserves.reserve0;
        uint amount1 = balance1 - _reserves.reserve1;

        // burn amount
        _burn(address(this), token0Id, amount0);
        _burn(address(this), token1Id, amount1);

        uint winAmount;
        if (outcome == 2){
            winAmount = amount0/2 + amount1/2;
        }else if (outcome == 0){
            winAmount = amount0;
        }else if (outcome == 1){
            winAmount = amount1;
        }

        IERC20(marketDetails[marketIdentifier].tokenC).transfer(to, winAmount);

        emit WinningRedeemed(address(this), to);
    }

    function redeemStake(bytes32 marketIdentifier) external {
        (bool valid, uint8 outcome) = isMarketClosed(marketIdentifier);
        require(valid);

        (uint sToken0Id, uint sToken1Id) = getReserveTokenIds(marketIdentifier);
        uint sAmount0 = balanceOf(msg.sender, sToken0Id);
        uint sAmount1 = balanceOf(msg.sender, sToken1Id);
        
        uint winAmount;
        if (outcome == 2){    
            winAmount = sAmount0 + sAmount1;
        }else {
            Staking memory _staking = staking[marketIdentifier];
            StakingReserves memory _stakingReserves = stakingReserves[marketIdentifier];
            
            if (outcome == 0){
                _stakingReserves.reserveS0 -= sAmount0;
                winAmount = sAmount0;
                if (_staking.staker0 == msg.sender || _staking.staker0 == address(0)){
                    winAmount += _stakingReserves.reserveS1;
                    _stakingReserves.reserveS1 = 0;
                    _staking.staker0 = address(this);
                }
            }else if (outcome == 1) {
                _stakingReserves.reserveS1 -= sAmount1;
                winAmount = sAmount1;
                if (_staking.staker1 == msg.sender || _staking.staker1 == address(0)){
                    winAmount += _stakingReserves.reserveS0;
                    _stakingReserves.reserveS0 = 0;
                    _staking.staker1 = address(this);
                }
            }

            stakingReserves[marketIdentifier] = _stakingReserves;
            staking[marketIdentifier] = _staking;
        }

        IERC20(marketDetails[marketIdentifier].tokenC).transfer(msg.sender, winAmount);

        emit StakedRedeemed(address(this), msg.sender);
    }

    function setOutcome(uint8 outcome, bytes32 marketIdentifier) external {
        require(msg.sender == delegate);
        require(outcome < 3);
        
        StateDetails memory _stateDetails = stateDetails[marketIdentifier];
        if (_stateDetails.stage == uint8(Stages.MarketFunded) 
            && block.number > _stateDetails.expireAtBlock
            && _stateDetails.donEscalationLimit == 0
            && _stateDetails.donBufferBlocks != 0){
            // donEscalationLimit == 0, indicates direct transition to MarketResolve after Market expiry
            // But if donBufferPeriod == 0 as well, then transition to MarketClosed after Market expiry
            _stateDetails.stage = uint8(Stages.MarketResolve);
        }
        require(_stateDetails.stage == uint8(Stages.MarketResolve) && block.number < _stateDetails.resolutionEndsAtBlock);

        MarketDetails memory _marketDetails = marketDetails[marketIdentifier];

        uint fee;
        if (outcome != 2 && _marketDetails.feeNumerator != 0){
            StakingReserves memory _stakingReserves = stakingReserves[marketIdentifier];
            if (outcome == 0) {
                fee = (_stakingReserves.reserveS1*_marketDetails.feeNumerator)/_marketDetails.feeDenominator;
                _stakingReserves.reserveS1 -= fee;
            }
            if (outcome == 1) {
                fee = (_stakingReserves.reserveS0*_marketDetails.feeNumerator)/_marketDetails.feeDenominator;
                _stakingReserves.reserveS0 -= fee;
            }
            stakingReserves[marketIdentifier] = _stakingReserves;
        }


        _stateDetails.outcome = outcome;
        _stateDetails.stage = uint8(Stages.MarketClosed);
        stateDetails[marketIdentifier] = _stateDetails;

        IERC20(marketDetails[marketIdentifier].tokenC).transfer(msg.sender, fee);

        emit OutcomeSet(address(this));
    }

    function updateMarketConfig(
        bool _isActive, 
        uint8 _feeNumerator, 
        uint8 _feeDenominator,
        uint16 _donEscalationLimit, 
        uint32 _expireBufferBlocks, 
        uint32 _donBufferBlocks, 
        uint32 _resolutionBufferBlocks
    ) external {
        MarketConfig memory _marketConfig;
        marketConfig.isActive = _isActive;
        marketConfig.feeNumerator = _feeNumerator;
        marketConfig.feeDenominator = _feeDenominator;
        marketConfig.donEscalationLimit = _donEscalationLimit;
        marketConfig.expireBufferBlocks = _expireBufferBlocks;
        marketConfig.donBufferBlocks = _donBufferBlocks;
        marketConfig.resolutionBufferBlocks = _resolutionBufferBlocks;
        marketConfig = _marketConfig;
    }

    function updateCollateralToken(address token) external {
        collateralToken = token;
    }

    function updateDelegate(address _delegate) external {
        require(msg.sender == delegate);
        delegate = _delegate;
    }
}
