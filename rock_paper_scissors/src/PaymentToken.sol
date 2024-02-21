// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PaymentToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("PaymentToken", "PTK") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address account, uint256 value) external {
        _mint(account, value);
    }

}