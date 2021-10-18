//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LLTH is ERC20, Ownable {
    constructor() ERC20("Lilith", "LLTH") {
        _mint(owner(), 1000000 * (10**18));
    }
}
