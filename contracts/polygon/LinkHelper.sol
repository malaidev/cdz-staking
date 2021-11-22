// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";



contract LinkHelper is ChainlinkClient {
    
    using Chainlink for Chainlink.Request;
    constructor() {
       
        // LINK token address on Polygon Mumbai testnet ONLY (Change to main net address before production deployment)
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);

    }

    LinkTokenInterface LINK = LinkTokenInterface(chainlinkTokenAddress());


    function approveLink(address _spender, uint _amount) public {
        LINK.approve(_spender, _amount);
    }

    
    function sendLink(address payable _to, uint _amount) public {
        LINK.transfer(_to, _amount);
    }

}
