/*

### TO DO - BEFORE PRODUCTION DEPLOYMENT ###


Change Chainlink oracle params to Polygon main net:
- Link token address (0xb0897686c545045afc77cf20ec7a532e3120e0f1)
- oracle addres (0x0a31078cD57d23bf9e8e8F1BA78356ca2090569E)
- job ID (12b86114fa9e46bab3ca436f88e1a912)
- fee (0.01 LINK)
(https://market.link/jobs/56666c3e-534d-490f-8757-521928739291)


Remove testSetData() function from bottom

*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "../mocks/IxLLTH.sol";

contract Harvest is Ownable, ChainlinkClient {
    /**
        @notice xLLTH token
     */
    IxLLTH public xLLTH;

    using Address for address;
    using Chainlink for Chainlink.Request;

    struct UserData {
        uint256[] tokens;
        uint256 stakingTimestamp;
        address user;
        address collection;
    }

    struct CollectionData {
        uint256 multiplier;
        uint256 amountOfStakers;
        uint256 harvestCooldown;
        uint256 harvestFee;
        address collection;
        bool isStakable;
    }

    struct HarvestInfo {
        address userAddress;
        address collection;
        bool liveOracleCall;
    }

    uint256 private fee;
    address public devAddress;

    string public apiUrlBase = "http://cdz-express-api-testing.herokuapp.com/"; // Example: http://localhost:3000/

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
    constructor(address xLLTHaddress) {
        xLLTH = IxLLTH(xLLTHaddress);

        // GET => uint oracle
        oracle = 0xc8D925525CA8759812d0c299B90247917d4d4b7C; // Polygon Mumbai testnet ONLY
        jobId = "bbf0badad29d49dc887504bacfbb905b"; // // Polygon Mumbai testnet ONLY
        oracleFee = 0.01 * 10**18; // (Varies by network and job)

        // LINK token address on Polygon Mumbai testnet ONLY
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB); // Polygon Mumbai testnet ONLY
    }

    // --- MAPPINGS ---

    mapping(bytes32 => UserData) userDataMap;

    mapping(address => CollectionData) collectionDataMap;

    mapping(bytes32 => HarvestInfo) idToHarvestInfo;

    mapping(bytes32 => uint256) tokensLeftToHarvest;

    mapping(bytes32 => uint256) pendingBalance;

    // only LINK tokens can be withdrawn
    receive() external payable {}

    // --- PUBLIC FUNCTIONS ---

    function feeForHarvest(address _collection) public payable {
        require(
            msg.value >= collectionDataMap[_collection].harvestFee,
            "Harvest.feeForHarvest: Fee not covered"
        );
        (bool success, ) = payable(devAddress).call{ value: msg.value }("");
        require(success, "Harvest.feeForHarvest: Tranfer failed");
    }

    function harvest(address _collection) public {
        bytes32 hash = keccak256(abi.encodePacked(msg.sender, _collection));

        UserData storage userData = userDataMap[hash];
        CollectionData storage collectionData = collectionDataMap[_collection];

        require(
            ((block.timestamp - userData.stakingTimestamp) / 60 / 60 / 24) >=
                collectionData.harvestCooldown,
            "Harvest.harvest: You are on cooldown"
        );

        require(
            userData.user == msg.sender,
            "Harvest.harvest: Tempered user address"
        );
        require(
            collectionData.isStakable == true,
            "Harvest.harvest: Staking isn't available in given pool"
        );
        require(
            collectionData.amountOfStakers != 0,
            "Harvest.harvest: You can't harvest, if pool is empty"
        );

        require(tokensLeftToHarvest[hash] == 0, "Harvest already in progress"); // stops users harvesting again whilst fulfill() callback calls are still ongoing

        // stores uint of how many tokens to get rarity score of. Accessed in fulfill() callback function
        tokensLeftToHarvest[hash] = userData.tokens.length;

        for (uint256 x; x < userData.tokens.length; ++x) {
            _getRarity(userData.user, userData.collection, userData.tokens[x]);
        }
    }

    /**
     * Creates a Chainlink request to retrieve API response.
     */
    function _getRarity(
        address _user,
        address _collection,
        uint256 _tokenId
    ) internal {
        Chainlink.Request memory request = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        string memory fullURL = returnFullURL(_collection, _tokenId);

        // Set the URL to perform the GET request on
        request.add("get", fullURL);

        // Sends the request
        bytes32 requestId = sendChainlinkRequestTo(oracle, request, oracleFee);

        idToHarvestInfo[requestId].liveOracleCall = true;

        // stores user address for access in fulfill callback function
        idToHarvestInfo[requestId].userAddress = _user;
        idToHarvestInfo[requestId].collection = _collection;
    }

    /**
     * Receive the response in the form of uint256
     */
    function fulfill(bytes32 _requestId, uint256 _rarity)
        public
        recordChainlinkFulfillment(_requestId)
    {
        require(msg.sender == oracle);
        require(idToHarvestInfo[_requestId].liveOracleCall);
        idToHarvestInfo[_requestId].liveOracleCall = false;

        address user = idToHarvestInfo[_requestId].userAddress;
        address collection = idToHarvestInfo[_requestId].collection;

        bytes32 hash = keccak256(abi.encodePacked(user, collection));

        UserData storage userData = userDataMap[hash];
        CollectionData storage collectionData = collectionDataMap[collection];

        uint256 daysStaked = (block.timestamp - userData.stakingTimestamp) /
            (24 * 60 * 60);

        uint256 reward = _getReward(
            _rarity,
            daysStaked,
            collectionData.multiplier,
            collectionData.amountOfStakers
        );

        pendingBalance[hash] += reward;

        tokensLeftToHarvest[hash]--;

        if (tokensLeftToHarvest[hash] == 0) {
            // if all NFT rewards of a user's collection have been calculated then transfer tokens
            xLLTH.mintForGames(user, pendingBalance[hash] * (10**18));
            pendingBalance[hash] = 0;
        }
    }

    // --- INTERNAL FUNCTIONS ---

    /**
     *    @notice converts a uint to a string
     *    @param _i => the uint to convet
     */
    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    /**
     *    @notice converts an address to a string
     *    @param _address => the address to convet
     */
    function addressToString(address _address)
        internal
        pure
        returns (string memory)
    {
        return toString(abi.encodePacked(_address));
    }

    /**
     *    @notice converts bytes to a string
     *    @param data => the bytes to convet
     */
    function toString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    // --- VIEW FUNCTIONS ---

    /**
     *    @notice builds full URL for API call
     *    @param _collection => address of NFT collection
     *    @param _tokenId => tokenId of token
     */
    function returnFullURL(address _collection, uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        string memory collectionAddress = addressToString(_collection);
        string memory tokenId = uint2str(_tokenId);
        string memory fullURL = string(
            abi.encodePacked(
                apiUrlBase,
                "?address=",
                collectionAddress,
                "&id=",
                tokenId
            )
        );
        return fullURL;
    }

    /**
     * @dev View LINK token balance of smart contract
     */
    function viewLinkBalance() public view returns (uint256) {
        LinkTokenInterface LINK = LinkTokenInterface(chainlinkTokenAddress());
        return LINK.balanceOf(address(this));
    }

    /**
     *    @notice calculate rewards of each NFT based on our formula
     *    {see whitepaper for clear explanation}
     */
    function _getReward(
        uint256 _rarity,
        uint256 _daysStaked,
        uint256 _multiplier,
        uint256 _amountOfStakers
    ) internal pure returns (uint256) {
        uint256 baseMultiplier = _multiplier * _daysStaked;
        uint256 basemultiplierxRarity = baseMultiplier * _rarity;
        uint256 finalReward = basemultiplierxRarity / _amountOfStakers;

        return finalReward;
    }

    // --- ADMIN FUNCTIONS ---

    function setData(
        uint256[] memory _tokens,
        uint256 _stakingTimestamp,
        uint256 _multiplier,
        uint256 _amountOfStakers,
        uint256 _harvestCooldown,
        uint256 _harvestFee,
        address _user,
        address _collection,
        bool _isStakable
    ) public onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(_user, _collection));

        userDataMap[hash] = UserData(
            _tokens,
            _stakingTimestamp,
            _user,
            _collection
        );

        collectionDataMap[_collection] = CollectionData(
            _multiplier,
            _amountOfStakers,
            _harvestCooldown,
            _harvestFee,
            _collection,
            _isStakable
        );
    }

    function setDev(address payable _newDev) public onlyOwner {
        require(devAddress != _newDev, "Harvest.setDev: Address already set");
        devAddress = _newDev;
    }

    function setOracleParams(
        string memory _apiUrlBase,
        address _oracleAddress,
        bytes32 _jobId,
        uint256 _oracleFee
    ) public onlyOwner {
        apiUrlBase = _apiUrlBase;
        oracle = _oracleAddress;
        jobId = _jobId;
        oracleFee = _oracleFee;
    }

    /**
     * @dev Reset the state of a harvest in the event that not all callbacks are successful
     */
    function resetHarvest(address _user, address _collection) public onlyOwner {
        bytes32 hash = bytes32(abi.encodePacked(_user, _collection));
        pendingBalance[hash] = 0;
        tokensLeftToHarvest[hash] = 0;
    }

    /**
     * @dev Withdraw all LINK tokens from smart contract to address '_to'
     */
    function withdrawLink(address payable _to) public onlyOwner {
        LinkTokenInterface LINK = LinkTokenInterface(chainlinkTokenAddress());
        LINK.transfer(_to, LINK.balanceOf(address(this)));
    }

    // TESTING ONLY

    function setTestData(uint256[] memory tokenIds) public onlyOwner {
        setData(
            tokenIds,
            block.timestamp - (24 * 60 * 60),
            1,
            1,
            0,
            0,
            msg.sender,
            0xAE16529eD90FAfc927D774Ea7bE1b95D826664E3,
            true
        );
    }
}
