pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLLTH is ERC20 {
    constructor() ERC20("mockLLTH", "mLLLTH") public {
        //_mint(msg.sender, 1000000*(10**18)); 
    }

    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }
}

