//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

/**
 * @title Cryptodemonz NFT staking contract
 * @author lawrence_of_arabia & kisile
 */

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./mocks/MockLLTH.sol";
import "./libs/Array.sol";

contract Masterdemon is Ownable, ReentrancyGuard {
    using Address for address;
    using Array for uint256[];

    /**
     *    @notice keep track of each user and their info
     *
     *    'stakedTokens' => mapping of collection address and array of staked ids
     *    in given collection.
     *    'amountStaked' => keep track of total amount of nfts staked in any pool
     *    'userBalance' => somewhat unnecessary addition, to keep track of user rewards.
     *    this becomes always 0 after _harvest, so removing it might be a good thing.
     *     'timeStaked' => staking period in given collection
     */
    struct UserInfo {
        mapping(address => uint256[]) stakedTokens;
        mapping(address => uint256) timeStaked;
        uint256 amountStaked;
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
     *    'requiredTimeToGetRewards' => represented in days, user must take this many days to get rewards
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
     *    @notice map user addresses over their info
     */
    mapping(address => UserInfo) public userInfo;

    /**
     *    @notice collection address => (staked nft => user address)
     */
    mapping(address => mapping(uint256 => address)) public tokenOwners;

    /**
     *   @notice collection address => nft rarities where index = nft id
     *   @dev extremely heavy array warning, traversing is suicide!
     */
    mapping(address => uint256[]) public tokenRarities;

    /**
     *   @notice array of each collection, we search through this by _cid (collection identifier)
     */
    CollectionInfo[] public collectionInfo;

    /**
     *   @notice Lilith token
     */
    MockLLTH public llth;

    /**
     *   @notice dev address for fees
     */
    address payable devAddress;

    constructor(MockLLTH _llth) public {
        llth = _llth;
    }

    /*-------------------------------Main external functions-------------------------------*/

    function stake(uint256 _cid, uint256 _id) external {
        sendFee(devAddress, collectionInfo[_cid].stakingFee);
        _stake(msg.sender, _cid, _id);
    }

    function batchStake(uint256 _cid, uint256[] memory _ids) external {
        for (uint256 i = 0; i < _ids.length; ++i) {
            _stake(msg.sender, _cid, _ids[i]);
        }
    }

    function unstake(uint256 _cid, uint256 _id) external {
        _unstake(msg.sender, _cid, _id);
    }

    function batchUnstake(uint256 _cid, uint256[] memory _ids) external {
        for (uint256 i = 0; i < _ids.length; ++i) {
            _unstake(msg.sender, _cid, _ids[i]);
        }
    }

    /*-------------------------------Main internal functions-------------------------------*/

    /**
    *    @notice internal stake function, called in external stake and batchStake
    *    @param _user => msg.sender
    *    @param _cid => collection id, to get correct one from array
    *    @param _id => nft id
    *
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
        user.timeStaked[collection.collectionAddress] = block.timestamp;
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

        user.timeStaked[collection.collectionAddress] = 0;
        user.amountStaked -= 1;

        if (user.amountStaked == 0) {
            delete userInfo[_user];
        }
    }

    /**
        @notice safer way to send ethereum, will revert on fail
        @param _to => dev address in our case
        @param _value => how much ethereum
     */
    function sendFee(address payable _to, uint256 _value) public payable {
        (bool sent, bytes memory data) = _to.call{ value: _value }("");
        require(sent, "Harvest.sendFee: Failed to send fee");
    }

    /*-------------------------------Admin functions-------------------------------*/

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
                amountOfStakers: 0,
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

    function setDev(address payable _newDev) public onlyOwner {
        require(devAddress != _newDev, "Masterdemon.setDev: Value already set");
        devAddress = _newDev;
    }

    /*-------------------------------Get functions for frontend-------------------------------*/

    function getUserInfo(address _user, address _collection)
        public
        view
        returns (
            uint256[] memory,
            uint256,
            uint256,
            uint256
        )
    {
        UserInfo storage user = userInfo[_user];
        return (
            user.stakedTokens[_collection],
            user.timeStaked[_collection],
            user.amountStaked,
            user.userBalance
        );
    }

    function getCollectionInfo(uint256 _cid)
        public
        view
        returns (
            bool,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        CollectionInfo memory collection = collectionInfo[_cid];
        return (
            collection.isStakable,
            collection.collectionAddress,
            collection.harvestingFee,
            collection.multiplier,
            collection.maturityPeriod,
            collection.amountOfStakers,
            collection.stakingLimit
        );
    }

    /*-------------------------------Misc-------------------------------*/

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

    receive() external payable {}
}
