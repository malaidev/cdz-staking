// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract FxERC20 is ERC20 {

    address internal _fxManager;

    mapping(address => bool) public managers;

    address internal _owner;

    constructor() ERC20('Test', 'TEST') {
        _owner = msg.sender;
    }

    /**@dev Allows execution by managers only */
    modifier managerOnly() {
        require(managers[msg.sender]);
        _;
    }

    /**@dev Be careful setting new manager, recheck the address */
    function setManager(address manager, bool state) external {
        require(msg.sender == _owner, "Only admin.");
        managers[manager] = state;
    }

    
    function mintForGames(address user, uint256 amount) public managerOnly {
        _mint(user, amount);
    }
}