//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./mocks/MockLLTH.sol";
import "./provableAPI.sol";
import "./libs/Array.sol";

contract Masterdemon is Ownable, ReentrancyGuard, usingProvable {
    using Address for address;
    using Array for uint256[];
    
    
    string public apiURL = "https://www.random.org/integers/?num=1&min=50&max=350&col=1&base=10&format=plain&rnd=new"; // random number API. Returns number between 50 & 350
    uint256 public oracleCallbackGasLimit;
    
    /**
     *    @notice keep track of info needed in __callback() function
     *
     *    'userAddress' => address of the user calling the harvest() function
     *    'collectionAddress' => address of collection user is harvesting rewards of
     *    'cid' => identifier of collection user is harvesting rewards of
     */
    struct harvesterInfo {
        address userAddress;
        address collectionAddress;
        uint cid;
    }
    
    /**
     *    @notice keep track of each user and their info
     *
     *    'stakedTokens' => mapping of collection address and array of staked ids
     *    in given collection.
     *    'amountStaked' => keep track of total amount of nfts staked in any pool
     *    'userBalance' => somewhat unnecessary addition, to keep track of user rewards.
     *    this becomes always 0 after _harvest, so removing it might be a good thing.
     */
    struct UserInfo {
        mapping(address => uint256[]) stakedTokens;
        uint256 amountStaked;
        uint256 stakedTimestamp;
        uint256 userBalance;
    }

    /**
     *    @notice keep track of each collection and their info
     *
     *    'isStakable' => instead of deleting the collection from mapping/array,
     *    we use simple bool to disable it. By this we avoid possible complications
     *    of holes in arrays (due to lack of deleting items at index in solidity),
     *    sacrificing overall performance.
     *    'collectionAddress' => ethereum address of given contract
     *    'stakingFee' => simple msg.value
     *    'harvestingFee' => simple msg.value
     *    'multiplier' => boost collections by increasing rewards
     *    'maturityPeriod' => represented in days, this will assure that user has to
     *    stake for "some time" to start accumulating rewards
     *    'amountOfStakers' => amount of people in given collection, used to decrease
     *    rewards as collection popularity rises
     *    'stakingLimit' => another limitation, represented in amount of staked nfts per user in
     *    particular collection. Users can stake freely before they reach this limit and
     *    again, either they cheat through staking from other account or they move to another
     *    pool.
     */
    struct CollectionInfo {
        bool isStakable;
        address collectionAddress;
        uint256 stakingFee;
        uint256 harvestingFee;
        uint256 multiplier;
        uint256 maturityPeriod;
        uint256 amountOfStakers;
        uint256 stakingLimit;
    }
    
    
    /**
     *    @notice emitted when oracle query sent
     */
    event LogNewProvableQuery(string description);

    /**
     *    @notice emitted when oracle calls __callback() function
     */
    event Callback(string result);
    
    
    /**
     *    @notice map hash of user address and cid, to the number of staked tokens owned by a user for a specfic collection to harvest. 
     */
    mapping(bytes32 => uint) loopsLeft;
    
    /**
     *    @notice map oracle query id to struct harvesterInfo for access in __callback()
     */
    mapping(bytes32 => harvesterInfo) idToHarvesterInfo;
    
    /**
     *    @notice map status of pending oracle queries
     */
    mapping(bytes32 => bool) pendingQueries;

    /**
     *    @notice map user addresses over their info
     */
    mapping(address => UserInfo) public userInfo;

    /**
     *    @notice colleciton address => (staked nft => user address)
     *    @dev would be nice if replace uint256 to uint256[]
     */
    mapping(address => mapping(uint256 => address)) public tokenOwners;

    /**
     *   @notice array of each collection, we search through this by _cid (collection identifier)
     */
    CollectionInfo[] public collectionInfo;

    /**
        @notice Lilith token
     */
    MockLLTH public llth;

    constructor(MockLLTH _llth) public {
        llth = _llth;

        provable_setCustomGasPrice(200000000000); // 200 gwei gas price  // MUST RUN BRIDGE IF NOT COMMENTED OUT

        // TESTING PURPOSES ONLY - for testing oracle queries on locally run blockchain %%%%%%%%%
        OAR = OracleAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475); // %%%%%%%%%%%%%%%
    }

    function stake(uint256 _cid, uint256 _id) external {
        _stake(msg.sender, _cid, _id);
    }

    function batchStake(uint256 _cid, uint256[] memory _ids) external {
        for (uint256 i=0; i < _ids.length; ++i) {
            _stake(msg.sender, _cid, _ids[i]);
        }
    }

    function unstake(uint256 _cid, uint256 _id) external {
        _unstake(msg.sender, _cid, _id);
    }

    function batchUnstake(uint256 _cid, uint256[] memory _ids) external {
        for (uint256 i=0; i < _ids.length; ++i) {
            _unstake(msg.sender, _cid, _ids[i]);
        }
    }

    function harvest(uint256 _cid) external {
        _harvest(msg.sender, _cid);
    }

    /**
    *    @notice internal stake function, called in external stake and batchStake
    *    @param _user => msg.sender
    *    @param _cid => collection id, to get correct one from array
    *    @param _id => nft id

    *    - First we have to check if user reached the staking limitation.
    *    - We transfer their NFT to contract
    *    - If user never staked here before, we increment amountOfStakers
    *    - increment amountStaked by 1
    *    - Start tracking of daysStaked with stakedTimestamp
    *    - populate stakedTokens mapping
    *    - populate tokenOwners double mapping with user's address
     */
    function _stake(
        address _user,
        uint256 _cid,
        uint256 _id
    ) internal {
        UserInfo storage user = userInfo[_user];
        CollectionInfo storage collection = collectionInfo[_cid];

        require(
            user.stakedTokens[collection.collectionAddress].length <
                collection.stakingLimit,
            "Masterdemon._stake: You can't stake more"
        );

        IERC721(collection.collectionAddress).safeTransferFrom(
            _user,
            address(this),
            _id
        );

        if (user.stakedTokens[collection.collectionAddress].length == 0) { 
            collection.amountOfStakers += 1;
        }

        user.amountStaked += 1;
        user.stakedTimestamp = block.timestamp;
        user.stakedTokens[collection.collectionAddress].push(_id);
        tokenOwners[collection.collectionAddress][_id] = _user;
    }

    /**
     *    @notice internal unstake function, called in external unstake and batchUnstake
     *    @param _user => msg.sender
     *    @param _cid => collection id, to get correct one from array
     *    @param _id => nft id
     *
     *    - Important require statement checks if user really staked in given collection
     *    with help of double mapping
     *    - If it's okay, we return the tokens, without minting any rewards
     *    - Next several lines are for delicate array manipulation
     *    - delete id from stakedTokens mapping => array
     *    - delete user from tokenOwners double mapping
     *    - reset user's daysStaked to zero %%%%%%%%%%%%%%% might cause issues
     *    - if user has nothing left in given collection, deincrement amountOfstakers
     *    - if user has nothing staked at all (in any collection), delete their struct
     */
    function _unstake(
        address _user,
        uint256 _cid,
        uint256 _id
    ) internal {
        UserInfo storage user = userInfo[_user];
        CollectionInfo storage collection = collectionInfo[_cid];

        require(
            tokenOwners[collection.collectionAddress][_id] == _user,
            "Masterdemon._unstake: Sender doesn't owns this token"
        );

        
        IERC721(collection.collectionAddress).safeTransferFrom(
            address(this),
            _user,
            _id
        );

        user.stakedTokens[collection.collectionAddress].removeElement(_id);

        if (user.stakedTokens[collection.collectionAddress].length == 0) {
            collection.amountOfStakers -= 1;
        }
        
        // delete will leave 0x000...000
        delete tokenOwners[collection.collectionAddress][_id];

        user.stakedTimestamp = 0;
        user.amountStaked -= 1;

        //if (user.amountStaked == 0) {
        //    delete userInfo[_user];
        //}
    }

    /**
     *    @notice internal _harvest function, called in external harvest
     *    @param _user => msg.sender
     *    @param _cid => collection id
     *
     *    - Calculating daysStaked by converting unix epoch to days (dividing on 60 / 60 / 24)
     *    - Collection must be stakable
     *    - daysStaked must be over maturityPeriod of given collection
     *    - To sum rewards from every single nft staked in given collection, we are looping
     *    thru user.stakedTokens mapping of address => array.
     *    - Check rarity of each token, calculate rewards and push them into user.userBalance
     *    - Mint rewards
     *    - Reset userBalance to 0.
     */
    function _harvest(address _user, uint256 _cid) internal {
        UserInfo storage user = userInfo[_user];
        CollectionInfo memory collection = collectionInfo[_cid];

        uint256 userTokensStakedInPool = user.stakedTokens[collection.collectionAddress].length;
        require(userTokensStakedInPool > 0, "You have no tokens staked in this pool");

        uint256 daysStaked;
        if (user.stakedTimestamp == 0) { // i.e. token not currently being staked
            daysStaked = 0;
        } else {
            daysStaked = (block.timestamp - user.stakedTimestamp) / 86400;
        }

        require(
            daysStaked >= collection.maturityPeriod,
            "Masterdemon._harvest: You can't harvest yet"
        );

        require(
            collection.isStakable == true,
            "Masterdemon._harvest: Staking in given pool has finished"
        );

        bytes32 hash = bytes32(abi.encodePacked(_user,_cid));


        // adjust to handle the instance where queries get stuck due to too low of a gas price
        require(loopsLeft[hash] == 0, "Harvest already in progress"); // stops users harvesting again whilst __callback() calls are still ongoing


        // stores uint of how many tokens to get rarity score of. Accessed in __callback() function
        loopsLeft[hash] = userTokensStakedInPool;
        
        for (
            uint256 i;
            i < userTokensStakedInPool;
            ++i
        ) {
            uint256 currentId = user.stakedTokens[collection.collectionAddress][
                i
            ];
            _getRarity(
                _user,
                _cid,
                collection.collectionAddress,
                currentId
            );
        }
    }


    function _getRarity(address _user, uint _cid, address _collectionAddress, uint256 _nftId) public payable { // % VISIBILTY MIGHT NEED CHANGING %%%%%%%%%%%%%%%%%%%%%%
        require(provable_getPrice("URL") < address(this).balance, "Not enough ether held in smart contract to cover oracle fee, contact admin");
            
        
        // string memory args = string(abi.encodePacked('{"nftId":', _nftId,', "collectionAddress": ', _collectionAddress,'}'));  // JUST AN EXAMPLE
        //bytes32 queryId = provable_query("URL", apiURL, args);
        bytes32 queryId = provable_query("URL", apiURL); // SPECIFY GAS LIMIT AS FINAL ARG. (Default is 200k, any unused gas goes to Provable) %%%%%%%%%
        // 97,403 gas used for _callback of older version (see https://rinkeby.etherscan.io/tx/0x58396b3e08cc251a1c1d5d082821f2d7af63f17bdda54509b0ebb80189f90670)

        
        pendingQueries[queryId] = true;
        emit LogNewProvableQuery("Provable query was sent, standing by for the answer..");
        
        idToHarvesterInfo[queryId].userAddress = _user; // stored so __callback function can retrieve this info later
        idToHarvesterInfo[queryId].cid = _cid; // stored so __callback function can retrieve this info later
    }
    
    
    // called by Provable oracle
    function __callback(bytes32 _myid, string memory _result) override public {
        require(msg.sender == provable_cbAddress()); // must be called by Provable oracle
        require (pendingQueries[_myid] == true);
        
        pendingQueries[_myid] == false;

        emit Callback(_result);
        
        uint rarity = parseInt(_result); 

        // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        rarity = 100; // for TESTING ONLY, ensures rarity score is always 100 %%%%%%%%%%%%%%%%%%
        // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        require(rarity >= 50 && rarity <= 350, "Masterdemon._harvest: Wrong range");
        
        address userAddress = idToHarvesterInfo[_myid].userAddress;
        UserInfo storage user = userInfo[userAddress];
        uint256 daysStaked = (block.timestamp - user.stakedTimestamp) / 86400; 
        
        uint cid = idToHarvesterInfo[_myid].cid;
        CollectionInfo memory collection = collectionInfo[cid];
        
        uint256 reward = _getReward(
            rarity,
            daysStaked,
            collection.multiplier,
            collection.amountOfStakers
        );
        
        user.userBalance += reward;
        
        bytes32 hash = bytes32(abi.encodePacked(userAddress, cid));
        loopsLeft[hash] --;
        uint numOfLoopsLeft = loopsLeft[hash];
            
        if (numOfLoopsLeft == 0) { // if all NFT rewards of a user's collection have been calculated then transfer tokens
            llth.mint(userAddress, user.userBalance);
            user.userBalance = 0;
            user.stakedTimestamp = block.timestamp; // resets stakedTimestamp
        }
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
        uint256 finalReward = basemultiplierxRarity / _amountOfStakers; // possible losses here due to solidity rounding down

        return finalReward;
    }

    /**
     *    @notice initialize new collection
     *    {see struct for param definition}
     */
    function setCollection(
        bool _isStakable,
        address _collectionAddress,
        uint256 _stakingFee,
        uint256 _harvestingFee,
        uint256 _multiplier,
        uint256 _maturityPeriod,
        uint256 _stakingLimit
    ) public onlyOwner {
        
        collectionInfo.push(
            CollectionInfo({
                isStakable: _isStakable,
                collectionAddress: _collectionAddress,
                stakingFee: _stakingFee,
                harvestingFee: _harvestingFee,
                multiplier: _multiplier,
                maturityPeriod: _maturityPeriod,
                amountOfStakers: 0, // notice, its for testing purposes. this should be 0 in production %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                stakingLimit: _stakingLimit
            })
        );
    }


    /**
     *    @notice update collection
     *    {see struct for param definition}
     */
    function updateCollection(
        uint256 _cid,
        bool _isStakable,
        address _collectionAddress,
        uint256 _stakingFee,
        uint256 _harvestingFee,
        uint256 _multiplier,
        uint256 _maturityPeriod,
        uint256 _stakingLimit
    ) public onlyOwner {
        CollectionInfo memory collection = collectionInfo[_cid];
        collection.isStakable = _isStakable;
        collection.collectionAddress = _collectionAddress;
        collection.stakingFee = _stakingFee;
        collection.harvestingFee = _harvestingFee;
        collection.multiplier = _multiplier;
        collection.maturityPeriod = _maturityPeriod;
        collection.stakingLimit = _stakingLimit;
    }

    /**
     *    @notice enable/disable collections
     *    @param _cid => collection id
     *    @param _isStakable => enable/disable
     */
    function manageCollection(uint256 _cid, bool _isStakable) public onlyOwner {
        CollectionInfo memory collection = collectionInfo[_cid];
        collection.isStakable = _isStakable;
    }

    /**
     *    @notice stop every single collection, BE CAREFUL
     *    @param _confirmationPin => dummy pin to avoid "missclicking"
     */
    function emergencyStop(uint256 _confirmationPin) public onlyOwner {
        require(
            _confirmationPin == 666,
            "Masterdemon.emergencyStop: Please provide the correct pin"
        );
        for (uint256 i = 0; i < collectionInfo.length; ++i) {
            CollectionInfo memory collection = collectionInfo[i];
            if (collection.isStakable = true) {
                collection.isStakable = false;
            }
        }
    }

    /**
     *    @notice set the gas price that the Provable oracle uses to call the __callback() function
     *    @param _newGasPrice => gas price in Wei
     */
    function setOracleGasPrice(uint _newGasPrice) public onlyOwner {
        provable_setCustomGasPrice(_newGasPrice);
    }

    /**
     *    @notice set the gas limit for the Provable oracle __callback() call. Unspent gas is retained by Provable.
     *    @param _newGasLimit => gas limit in Wei
     */
    function setOracleCallbackGasLimit(uint _newGasLimit) public onlyOwner {
        oracleCallbackGasLimit = _newGasLimit;
    }


    function getUser(address _user, address _collection) public view returns (uint256){
        UserInfo storage user = userInfo[_user];
        return user.amountStaked;
    }

    function getCollectionInfo(uint256 _cid) public view returns (uint256) {
        CollectionInfo memory collection = collectionInfo[_cid];
        return collection.amountOfStakers;
    }
    

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
    
    
    
    /**
     *    @notice Will receive any eth sent to the contract (funding oracle calls for example)
     */
    receive() external payable {}
    
    
    
    
    // TESTING ONLY %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function withdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }

    function mintLilith(uint _amount) public {
        llth.mint(msg.sender, _amount);
    }
    
    uint public price;
    function viewProvablePrice() public {
        price = provable_getPrice("URL");
    }
    // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




    // some get functions for testing and frontend
    function viewAmountOfStakers(uint256 _cid) public returns(uint) {
        CollectionInfo memory collection = collectionInfo[_cid];
        return collection.amountOfStakers;
    }

}