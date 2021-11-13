// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IOutcomeToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external;
    // function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external;
    function transferFrom(address sender, address recipient, uint256 amount) external;
    function issue(address to, uint256 amount) external;
}