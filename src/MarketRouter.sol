// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './libraries/TransferHelper.sol';
import './interfaces/IMarket.sol';
import './libraries/Math.sol';
import './interfaces/IMarketFactory.sol';


contract MarketRouter {
    address public factory;

    bytes32 constant public MARKET_INIT_CODE_HASH = 0xafd9d7476ae82bdc5f129b881537d33f4e31ac28cb51cabf0a9b8c07bdd19a34;

    constructor(address _factory) {
        factory = _factory;
    }


    /// @notice Contract address of a prediction market
    function getMarketAddress(address creator, address oracle, string memory identifier) public view returns (address marketAddress) {
        marketAddress = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encode(creator, oracle, identifier)),
                MARKET_INIT_CODE_HASH
            )))));
    }

    /// @notice Create, fund, and place bet on a market
    function createAndPlaceBetOnMarket(address _creator, address _oracle, string memory _identifier, uint _fundingAmount, uint _amountIn, uint _for) external {
        require(_for < 2 && _fundingAmount > 0);
        address marketAddress = IMarketFactory(factory).createMarket(_creator, _oracle, _identifier);

        (address tokenC,,) = IMarket(marketAddress).getTokenAddresses();

        // fund
        TransferHelper.safeTransferFrom(tokenC, msg.sender, marketAddress, _fundingAmount);
        IMarket(marketAddress).fund();

        TransferHelper.safeTransferFrom(tokenC, msg.sender, marketAddress, _amountIn);
        if (_for == 0) IMarket(marketAddress).buy(_amountIn, 0, msg.sender);
        if (_for == 1) IMarket(marketAddress).buy(0, _amountIn, msg.sender);
    }

    /// @notice Buy exact amountOfToken0 & amountOfToken1 with collteral tokens <= amountInCMax
    function buyExactTokensForMaxCTokens(uint amountOutToken0, uint amountOutToken1, uint amountInCMax, address market) external {
        (uint reserve0, uint reserve1) = IMarket(market).getOutcomeReserves();
        uint amountIn = Math.getAmountCToBuyTokens(amountOutToken0, amountOutToken1, reserve0, reserve1);
        require(amountInCMax >= amountIn, "TRADE: INVALID");
        (address tokenC,,) = IMarket(market).getTokenAddresses();
        TransferHelper.safeTransferFrom(tokenC, msg.sender, market, amountIn);
        IMarket(market).buy(amountOutToken0, amountOutToken1, msg.sender);
    }

    /// @notice Buy minimum amountOfToken0 & amountOfToken1 with collteral tokens == amountInC. 
    /// fixedTokenIndex - index to token of which amount does not change in reaction to prices 
    function buyMinTokensForExactCTokens(uint amountOutToken0Min, uint amountOutToken1Min, uint amountInC, uint fixedTokenIndex, address market) external {
        require(fixedTokenIndex < 2);

        (uint reserve0, uint reserve1) = IMarket(market).getOutcomeReserves();

        uint amountOutToken0 = amountOutToken0Min;
        uint amountOutToken1 = amountOutToken1Min;
        if (fixedTokenIndex == 0){
            amountOutToken1 = Math.getTokenAmountToBuyWithAmountC(amountOutToken0, fixedTokenIndex, reserve0, reserve1, amountInC);
        }else {
            amountOutToken0 = Math.getTokenAmountToBuyWithAmountC(amountOutToken1, fixedTokenIndex, reserve0, reserve1, amountInC);
        }
        require(amountOutToken0 >= amountOutToken0Min && amountOutToken1 >= amountOutToken1Min);

        (address tokenC,,) = IMarket(market).getTokenAddresses();
        TransferHelper.safeTransferFrom(tokenC, msg.sender, market, amountInC);
        IMarket(market).buy(amountOutToken0, amountOutToken1, msg.sender);
    }

    /// @notice Sell exact amountInToken0 & amountInToken1 for collateral tokens >= amountOutTokenCMin
    function sellExactTokensForMinCTokens(uint amountInToken0, uint amountInToken1, uint amountOutTokenCMin, address market) external {
        (uint reserve0, uint reserve1) = IMarket(market).getOutcomeReserves();
        uint amountOutTokenC = Math.getAmountCBySellTokens(amountInToken0, amountInToken1, reserve0, reserve1);
        require(amountOutTokenC >= amountOutTokenCMin, "TRADE: INVALID");


        (,address token0, address token1) = IMarket(market).getTokenAddresses();
        TransferHelper.safeTransferFrom(token0, msg.sender, market, amountInToken0);
        TransferHelper.safeTransferFrom(token1, msg.sender, market, amountInToken1);
        IMarket(market).sell(amountOutTokenC, msg.sender);
    }

    /// @notice Sell maximum of amountInToken0Max & amountInToken1Max for collateral tokens == amountOutTokenC
    /// fixedTokenIndex - index of token of which amount does not change in reaction to prices
    function sellMaxTokensForExactCTokens(uint amountInToken0Max, uint amountInToken1Max, uint amountOutTokenC, uint fixedTokenIndex, address market) external {
        require(fixedTokenIndex < 2);

        (uint reserve0, uint reserve1) = IMarket(market).getOutcomeReserves();

        uint amountInToken0 = amountInToken0Max;
        uint amountInToken1 = amountInToken1Max;
        if (fixedTokenIndex == 0){
            amountInToken1 = Math.getTokenAmountToSellForAmountC(amountInToken0, fixedTokenIndex, reserve0, reserve1, amountOutTokenC);
        }else {
            amountInToken0 = Math.getTokenAmountToSellForAmountC(amountInToken1, fixedTokenIndex, reserve0, reserve1, amountOutTokenC);
        }
        require(amountInToken0 <= amountInToken0Max && amountInToken1 <= amountInToken1Max, "TRADE: INVALID");

        (,address token0, address token1) = IMarket(market).getTokenAddresses();        
        TransferHelper.safeTransferFrom(token0, msg.sender, market, amountInToken0);
        TransferHelper.safeTransferFrom(token1, msg.sender, market, amountInToken1);
        IMarket(market).sell(amountOutTokenC, msg.sender);
    }

    /// @notice Stake amountIn for outcome _for 
    function stakeForOutcome(uint _for, uint amountIn, address market) external {
        require(_for < 2);
        
        (uint lastAmountStaked,,,) = IMarket(market).getStaking();
        require(lastAmountStaked*2 <= amountIn, "ERR: DOUBLE");

        (address tokenC,,) = IMarket(market).getTokenAddresses();        
        TransferHelper.safeTransferFrom(tokenC, msg.sender, market, amountIn);
        IMarket(market).stakeOutcome(_for, msg.sender);
    }

    /// @notice Redeem winning for outcome
    function redeemWinning(uint _for, uint amountInToken, address market) external {
        (,address token0, address token1) = IMarket(market).getTokenAddresses();        
        if (_for == 0) TransferHelper.safeTransferFrom(token0, msg.sender, market, amountInToken);
        if (_for == 1) TransferHelper.safeTransferFrom(token1, msg.sender, market, amountInToken);
        IMarket(market).redeemWinning(_for, msg.sender);
    }
}
