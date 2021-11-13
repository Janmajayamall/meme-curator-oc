// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './interfaces/IOutcomeToken.sol';

contract OutcomeToken is IOutcomeToken {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    address immutable market;

    constructor() {
        market = msg.sender;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public override {
        _transfer(msg.sender, recipient, amount);
    }

    function approve(address spender, uint256 amount) public virtual override{
        _approve(msg.sender, spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        _balances[sender] -= amount;
        _balances[recipient] += amount;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        _allowances[owner][spender] = amount;
    }

    function issue(address to, uint256 amount) public override virtual {
        require(msg.sender == market);
        _totalSupply += amount;
        _balances[to] += amount;
    }
}
