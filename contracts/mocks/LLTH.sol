pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LLTH is ERC20 {
    constructor() ERC20("mockLLTH", "mLLLTH") public {
        _mint(msg.sender, 1000000000*(10**18)); 
    }
}

