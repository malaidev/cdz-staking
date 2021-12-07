// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IxLLTH is IERC20{
 
    function mintForGames(address user, uint256 amount) external;
    
}