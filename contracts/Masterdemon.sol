//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./mocks/MockLLTH.sol";

contract Masterdemon is Ownable, ReentrancyGuard {
    using Address for address;

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
        uint256 daysStaked;
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
     *    'maxDaysForStaking' => each collection will have staking limit that will be
     *    represented in days. Users can stake freely before they reach this limit, then
     *    either they cheat thru staking from other account or they move to another pool
     *    'stakingLimit' => another limitation, represented in amount of staked nfts in
     *    particular collection. Users can stake freely before they reach this limit and
     *    again, either they cheat thru staking from other account or they move to another
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
        uint256 maxDaysForStaking;
        uint256 stakingLimit;
    }

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
     *   @notice array of each collection, we search thru this by _cid (collection address)
     */
    CollectionInfo[] public collectionInfo;

    /**
        @notice Lilith token
     */
    MockLLTH public llth;

    constructor(MockLLTH _llth) {
        llth = _llth;
    }

    function stake(uint256 _cid, uint256 _id) external {
        _stake(msg.sender, _cid, _id);
    }

    function batchStake(uint256 _cid, uint256[] memory _ids) external {
        for (uint256 i; i < _ids.length; ++i) {
            _stake(msg.sender, _cid, _ids[i]);
        }
    }

    function unstake(uint256 _cid, uint256 _id) external {
        _unstake(msg.sender, _cid, _id);
    }

    function batchUnstake(uint256 _cid, uint256[] memory _ids) external {
        for (uint256 i; i < _ids.length; ++i) {
            _unstake(msg.sender, _cid, _ids[i]);
        }
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
    *    - Start tracking of daysStaked with timestamp
    *    - populate stakedTokens mapping
    *    - populate tokenOwners double mapping with user's address
     */
    function _stake(
        address _user,
        uint256 _cid,
        uint256 _id
    ) internal {
        UserInfo storage user = userInfo[_user];
        CollectionInfo memory collection = collectionInfo[_cid];

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
        user.daysStaked = block.timestamp;
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
     *    - reset user's daysStaked
     *    - if user has nothing left in given collection, deincrement amountOfstakers
     *    - if user has nothing staked at all (in any collection), delete their struct
     */
    function _unstake(
        address _user,
        uint256 _cid,
        uint256 _id
    ) internal {
        UserInfo storage user = userInfo[_user];
        CollectionInfo memory collection = collectionInfo[_cid];

        require(
            tokenOwners[collection.collectionAddress][_id] == _user,
            "Masterdemon._unstake: Sender doesn't owns this token"
        );

        IERC721(collection.collectionAddress).safeTransferFrom(
            address(this),
            _user,
            _id
        );

        // also deletes the gaps
        for (
            uint256 i;
            i < user.stakedTokens[collection.collectionAddress].length;
            ++i
        ) {
            if (user.stakedTokens[collection.collectionAddress][i] == _id) {
                delete user.stakedTokens[collection.collectionAddress][i];
                user.stakedTokens[collection.collectionAddress][i] = user
                    .stakedTokens[collection.collectionAddress][
                        user.stakedTokens[collection.collectionAddress].length -
                            1
                    ];
                user.stakedTokens[collection.collectionAddress].pop();
            }
        }

        // delete will leave 0x000...000
        delete tokenOwners[collection.collectionAddress][_id];
        user.daysStaked = 0;

        if (user.stakedTokens[collection.collectionAddress].length == 0) {
            collection.amountOfStakers -= 1;
        }

        if (user.amountStaked == 0) {
            delete userInfo[_user];
        }
    }

    /**
     *    @notice internal _harvest function, called in external harvest
     *    @param _user => msg.sender
     *    @param _cid => collection id
     *
     *    - Calculating daysStaked by converting unix epoch to days (dividing on 60 / 60 / 24)
     *    - Collection must be stakable
     *    - daysStaked must be over maturityPeriod of given collection
     *    - daysStaked must be less than maxDaysForStaking limitation of given collection
     *    - To sum rewards from every single nft staked in given collection, we are looping
     *    thru user.stakedTokens mapping of address => array.
     *    - Check rarity of each token, calculate rewards and push them into user.userBalance
     *    - Mint rewards
     *    - Reset userBalance to 0.
     */
    function _harvest(address _user, uint256 _cid) internal {
        UserInfo storage user = userInfo[_user];
        CollectionInfo memory collection = collectionInfo[_cid];

        uint256 daysStaked = (block.timestamp - user.daysStaked) / 86400;

        require(
            collection.isStakable == true,
            "Masterdemon._harvest: Staking in given pool has finished"
        );
        require(
            daysStaked >= collection.maturityPeriod,
            "Masterdemon._harvest: You can't harvest yet"
        );
        require(
            daysStaked < collection.maxDaysForStaking,
            "Masterdemon._harvest: You have reached staking period limit"
        );

        for (
            uint256 i;
            i < user.stakedTokens[collection.collectionAddress].length;
            ++i
        ) {
            uint256 currentId = user.stakedTokens[collection.collectionAddress][
                i
            ];
            uint256 rarity = _getRarity(
                collection.collectionAddress,
                currentId
            );
            require(
                rarity >= 50 && rarity <= 350,
                "Masterdemon._harvest: Wrong range"
            );
            uint256 reward = _getReward(
                rarity,
                user.daysStaked,
                collection.multiplier,
                collection.amountOfStakers
            );
            user.userBalance += reward;
        }

        llth.mint(_user, user.userBalance);
        user.userBalance = 0;
    }

    /**
     *   @notice dummy function, needs implementation
     */
    function _getRarity(address _collectionAddress, uint256 _nftId)
        internal
        returns (uint256 rarity)
    {
        rarity = 100; // dummy
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
        uint256 _maxDaysForStaking,
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
                amountOfStakers: 200, // notice, its for testing purposes. this should be 0 in production
                maxDaysForStaking: _maxDaysForStaking,
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
        uint256 _maxDaysForStaking,
        uint256 _stakingLimit
    ) public onlyOwner {
        CollectionInfo memory collection = collectionInfo[_cid];
        collection.isStakable = _isStakable;
        collection.collectionAddress = _collectionAddress;
        collection.stakingFee = _stakingFee;
        collection.harvestingFee = _harvestingFee;
        collection.multiplier = _multiplier;
        collection.maturityPeriod = _maturityPeriod;
        collection.maxDaysForStaking = _maxDaysForStaking;
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
}
