// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, 10000 ether);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        require(value > 0, "ERC20: transfer amount must be greater than zero");
        require(balanceOf(msg.sender) >= value, "ERC20: transfer amount exceeds balance");

        _update(msg.sender, to, value);
        return true;
    }
}
