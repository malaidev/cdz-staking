// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "./mocks/MockLLTH.sol";
import "./mocks/MockCollection.sol";

contract Harvest is Ownable, ChainlinkClient {
    
    
    /**
        @notice Lilith token
     */
    MockLLTH public llth;

    using Address for address;
    using Chainlink for Chainlink.Request;

    struct Data {
        uint256[] tokens;
        uint256 stakingPeriod;
        uint256 amountOfStakers;
        address user;
        address collection;
        bool isStakable;
    }

    struct HarvestInfo {
        address userAddress;
        bool liveOracleCall;
    }

    uint256 private fee;
    address payable devAddress;
  
    uint256 public rarity; // TEST PURPOSES ONLY

    string public apiURL = "https://www.random.org/integers/?num=1&min=50&max=350&col=1&base=10&format=plain&rnd=new"; // random number API (50-350)
    address private oracle;
    bytes32 private jobId;
    uint256 private oracleFee;

    /**
     * GET => uint oracle
     *
     * https://market.link/jobs/5bfcaea1-82f5-428a-8695-774a3b9afbde
     * 
     * Network: Polygon Mumbai TESTNET
     */
    constructor(MockLLTH _llth) {
        
        llth = _llth; // sets address of LLTH token

        // LINK token address on Polygon Mumbai testnet ONLY (Change to main net address before production deployment)
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB); 
        
        oracle = 0xc8D925525CA8759812d0c299B90247917d4d4b7C; // Polygon Mumbai testnet ONLY
        jobId = "bbf0badad29d49dc887504bacfbb905b"; // // Polygon Mumbai testnet ONLY
        oracleFee = 0.01  * 10 ** 18; // (Varies by network and job)
    }


    mapping(address => Data) dataMap;
    
    mapping(bytes32 => HarvestInfo) idToHarvestInfo;


    mapping(bytes32 => uint) tokensLeftToHarvest;

    mapping(address => uint) pendingBalance;

   

    function setData(
        uint256[] memory _tokens,
        uint256 _stakingPeriod,
        uint256 _amountOfStakers,
        address _user,
        address _collection,
        bool _isStakable
    ) public onlyOwner {
        dataMap[_user] = Data(
            _tokens,
            _stakingPeriod,
            _amountOfStakers,
            _user,
            _collection,
            _isStakable
        );
    }

    function harvest() public payable {

        Data memory data = dataMap[msg.sender];

        require(
            msg.value >= fee, "Harvest.harvest: Cover fee"
        );
        require(
            data.user == msg.sender,
            "Harvest.harvest: Tempered user address"
        );
        require(
            data.isStakable == true,
            "Harvest.harvest: Staking isn't available in given pool"
        );
        require(
            data.amountOfStakers != 0,
            "Harvest.harvest: You can't harvest, if pool is empty"
        );

        // store data.tokens.length for use in fullfill callback function
        bytes32 hash = bytes32(abi.encodePacked(data.user, data.collection));

        // TO DO: adjust to handle the instance where fulfill callback never called
        require(tokensLeftToHarvest[hash] == 0, "Harvest already in progress"); // stops users harvesting again whilst fulfill() callback calls are still ongoing

        // stores uint of how many tokens to get rarity score of. Accessed in fulfill() callback function
        tokensLeftToHarvest[hash] = data.tokens.length;

        sendFee(devAddress, msg.value);

        for (uint256 x; x < data.tokens.length; ++x) {
            _getRarity(
                data.user,
                data.collection,
                data.tokens[x]
            );
        }

        
        /*
        sendFee(devAddress, msg.value);
        llth.mint(msg.sender, reward);
        */
    }

    /**
     * Creates a Chainlink request to retrieve API response.
     */
    function _getRarity(
        address user,
        address collection,
        uint256 tokenId
    ) public {

        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", apiURL); 
        
        // Sends the request
        bytes32 requestId = sendChainlinkRequestTo(oracle, request, oracleFee);

        idToHarvestInfo[requestId].liveOracleCall = true;

        // stores user address for access in fulfill callback function
        idToHarvestInfo[requestId].userAddress = user; 
    }

    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(
        bytes32 _requestId,
        uint256 _rarity
    ) public recordChainlinkFulfillment(_requestId) {

        require(idToHarvestInfo[_requestId].liveOracleCall);
        idToHarvestInfo[_requestId].liveOracleCall = false;

        rarity = _rarity; // TEST PURPOSES ONLY

        address user = idToHarvestInfo[_requestId].userAddress;

        Data memory data = dataMap[user];

        uint256 reward = _getReward(
            _rarity,
            data.stakingPeriod,
            data.amountOfStakers            
        );

        pendingBalance[user] += reward;

        bytes32 hash = bytes32(abi.encodePacked(data.user, data.collection));

        tokensLeftToHarvest[hash] --;

        if (tokensLeftToHarvest[hash] == 0) {
            // if all NFT rewards of a user's collection have been calculated then transfer tokens
            llth.mint(user, pendingBalance[user]);
            pendingBalance[user] = 0;
        }
    }

    

    function _getReward(
        uint _rarity,
        uint256 _stakingPeriod,
        uint256 _amountOfStakers
    ) internal pure returns (uint256) {
        return 100; // TEST PURPOSES ONLY
    }

    





   

    function sendFee(address payable _to, uint256 _value) public payable {
        (bool sent, bytes memory data) = _to.call{ value: _value }("");
        require(sent, "Harvest.sendFee: Failed to send fee");
    }

    function setFee(uint256 _value) public onlyOwner {
        require(fee != _value, "Harvest.setFee: Value already set to that");
        fee = _value;
    }

    function setDev(address payable _newDev) public onlyOwner {
        require(devAddress != _newDev, "Harvest.setDev: Address already set");
        devAddress = _newDev;
    }

    receive() external payable {}


    /**
     * @dev Withdraw all LINK tokens from smart contract to address '_to'
     */
    function withdrawLink(address payable _to) public onlyOwner { 
        LinkTokenInterface LINK = LinkTokenInterface(chainlinkTokenAddress());
        LINK.transfer(_to, LINK.balanceOf(address(this))); 
    }
    
    function setOracleParams(
        string memory _apiURL,
        address _oracleAddress,
        bytes32 _jobId, 
        uint _oracleFee
    ) public onlyOwner { 
        apiURL = _apiURL;
        oracle = _oracleAddress;
        jobId = _jobId;
        oracleFee = _oracleFee;
    }
}
