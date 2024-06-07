// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@klaytn/contracts/KIP/token/KIP7/KIP7.sol";
import "@klaytn/contracts/KIP/token/KIP7/extensions/KIP7Mintable.sol";

contract ADT is KIP7Mintable {
    constructor() KIP7("AirDrop Token", "ADT") {}
}
