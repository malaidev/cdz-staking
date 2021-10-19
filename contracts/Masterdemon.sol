//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
pragma abicoder v2; // using this so we can return struct in get function

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Masterdemon is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;

    struct UserInfo {
        uint256 amountStaked; // how many nfts did user staked
        uint256 currentReward; // how much reward should user get
        uint256 daysStaked; // unix epoch / 60 / 60 / 24
        uint256[] tokenIds; // ids of nfts user staked
        mapping(uint256 => uint256) tokenIndex; // for delicate operations
        mapping(address => mapping (uint256 => bool)) stakedInPools; // for checking if user really staked tokens
    }

    struct NftCollection {
        bool isStakable; // this can disable/enable pool 
        address collectionAddress; // nft collectiona address
        uint256 stakingFee; // fee to stake, adjustable
        uint256 harvestingFee; // fee to harvest, adjustable
        uint256 multiplier; // boost for certain pools
        uint256 maturityPeriod; // when will user start receiving rewards
        uint256 amountOfStakers; // used to decrease rewards as pool becomes bigger
        uint256 daysStakedMultiplier; // just like multiplier but will multiply the rewards after some time
        uint256 requiredDaysToMultiply; // "some time"
    }

    /// @notice address => each user
    mapping(address => UserInfo) public userInfo;

    /// @notice array of each nft collection
    NftCollection[] public nftCollection;

    /// @notice LLTH token
    IERC20 public llth;

    event UserStaked(address staker);
    event UserUnstaked(address unstaker);
    event UserHarvested(address harvester);

    constructor(IERC20 _llth) {
        llth = _llth;
    }

    // ------------------------ PUBLIC/EXTERNAL ------------------------ //

    function stake(uint256 _cid, uint256 _id) external payable {
        NftCollection memory collection = nftCollection[_cid];
        if (collection.stakingFee != 0) {
            require(msg.value == collection.stakingFee, "FEE NOT COVERED");
        }
        

        _stake(msg.sender, _cid, _id);
    }

    function unstake(uint256 _id, uint256 _cid) external {
        _unstake(msg.sender, _cid, _id);
    }

    function stakeBatch(uint256 _cid, uint256[] memory _ids) external payable {
        NftCollection memory collection = nftCollection[_cid];
        for (uint256 i = 0; i < _ids.length; ++i) {
            if (collection.stakingFee != 0) {
                require(msg.value == collection.stakingFee, "FEE NOT COVERED");
            }
            _stake(msg.sender, _cid, _ids[i]);
        }
    }

    function unstakeBatch(uint256[] memory _ids, uint256 _cid) external {
        for (uint256 i = 0; i < _ids.length; ++i) {
            _unstake(msg.sender, _cid, _ids[i]);
        }
    }

    function harvest(uint256 _cid, uint256 _id) external payable {
        NftCollection memory collection = nftCollection[_cid];
        if (collection.harvestingFee != 0) {
            require(msg.value == collection.harvestingFee, "FEE NOT COVERED");
        }
        _harvest(msg.sender, _cid, _id);
    }

    function batchHarvest(uint256 _cid, uint256[] memory _ids)
        external
        payable
    {
        NftCollection memory collection = nftCollection[_cid];
        for (uint256 i = 0; i < _ids.length; ++i) {
            if (collection.harvestingFee != 0) {
                require(
                    msg.value == collection.harvestingFee,
                    "FEE NOT COVERED"
                );
            }
            _harvest(msg.sender, _cid, _ids[i]);
        }
    }

    // ------------------------ INTERNAL ------------------------ //

    /// @notice stake single nft (called in external function)
    /// @param _user = msg.sender
    /// @param _cid = collection id
    /// @param _id = nft id
    function _stake(
        address _user,
        uint256 _cid,
        uint256 _id
    ) internal {
        NftCollection memory collection = nftCollection[_cid];
        UserInfo storage user = userInfo[_user];
        require(
            IERC721(collection.collectionAddress).ownerOf(_id) ==
                address(_user),
            "ERR: YOU DONT OWN THIS TOKEN"
        );
        IERC721(collection.collectionAddress).safeTransferFrom(
            _user,
            address(this),
            _id
        );
        user.amountStaked = user.amountStaked.add(1);
        user.tokenIds.push(_id);
        user.daysStaked = block.timestamp;
        user.stakedInPools[collection.collectionAddress][_id] = true;

        emit UserStaked(_user);
    }

    /// @notice unstake single nft (called in external function)
    /// @param _user = msg.sender
    /// @param _cid = collection id
    /// @param _id = nft id
    function _unstake(
        address _user,
        uint256 _cid,
        uint256 _id
    ) internal {
        NftCollection memory collection = nftCollection[_cid];
        UserInfo storage user = userInfo[_user];
        require(
            user.stakedInPools[collection.collectionAddress][_id] == true,
            "YOU DONW OWN THESE TOKENS AT GIVEN INDEX"
        );
        IERC721(collection.collectionAddress).safeTransferFrom(
            address(this),
            _user,
            _id
        );

        uint256 lastIndex = user.tokenIds.length - 1;
        uint256 lastIndexKey = user.tokenIds[lastIndex];
        uint256 tokenIdIndex = user.tokenIndex[_id];

        user.tokenIds[tokenIdIndex] = lastIndexKey;
        user.tokenIndex[lastIndexKey] = tokenIdIndex;
        if (user.tokenIds.length > 0) {
            user.tokenIds.pop();
            user.stakedInPools[collection.collectionAddress][_id] = false;
            delete user.tokenIndex[_id];
            user.amountStaked.sub(1);
        }

        user.daysStaked = 0;

        if (user.amountStaked == 0) {
            delete userInfo[msg.sender];
            collection.amountOfStakers.sub(1);
        }

        emit UserUnstaked(_user);
    }

    /// @notice during harvest, user gets rewards
    /// @param _user: user address
    /// @param _cid: collection id
    /// @param _id: nft id
    /// @dev not finished yet, uses some dummy values
    function _harvest(
        address _user,
        uint256 _cid,
        uint256 _id
    ) internal {
        NftCollection memory collection = nftCollection[_cid];
        UserInfo storage user = userInfo[_user];
        uint256 daysStaked = block.timestamp.sub(user.daysStaked);
        require(daysStaked <= collection.maturityPeriod, "YOU CANT HARVEST YET");
        require(collection.isStakable = true, "STAKING HAS FINISHED");
        uint256 rarity = _getRarity(collection.collectionAddress, _id);
        require(rarity >= 50 && rarity <= 350, "WRONG RANGE, CHECK NORMALIZER");
        uint256 reward = _calculateRewards(
            rarity,
            daysStaked,
            collection.multiplier,
            collection.amountOfStakers
        ); 
        if (collection.daysStakedMultiplier != 0 && user.daysStaked >= collection.requiredDaysToMultiply) {
            reward = reward.mul(collection.daysStakedMultiplier);
        }

        user.currentReward = user.currentReward.sub(reward);

        llth.transfer(_user, reward);
        emit UserHarvested(_user);
    }

    /// @notice dummy function, will be replaced by oracle later
    function _getRarity(address _collectionAddress, uint256 _id)
        internal
        pure
        returns (uint256)
    {
        uint256 rarity = 100;
        return rarity;
    }

    /// @notice will calculate rarity based on our formula
    /// @param _rarity number given my trait normalization formula
    /// @param _daysStaked maturity period
    /// @param _multiplier pool can have multiplier
    /// @param _amountOfStakers used to minimize rewards proportionally to pool popularity
    function _calculateRewards(
        uint256 _rarity,
        uint256 _daysStaked,
        uint256 _multiplier,
        uint256 _amountOfStakers
    ) internal pure returns (uint256) {
        uint256 baseMultiplier = _multiplier.mul(_daysStaked);
        uint256 basemultiplierxRarity = baseMultiplier.mul(_rarity);
        uint256 finalReward = basemultiplierxRarity.div(_amountOfStakers);

        return finalReward;
    }

    // ------------------------ GET for frontend ------------------------ //

    /*
    /// @notice get NftCollection struct for frontend
    function getCollectionInfo(uint256 _cid)
        public
        view
        returns (NftCollection memory)
    {
        NftCollection memory collection = nftCollection[_cid];
        return collection;
    }
    */

    // returning UserInfo is other story, since it contains nested mapping
    // compiler will throw an error that due to this, struct is sitting in storage
    // but returning a struct can only accept either memory or calldata
    // this needs to be fixed either with abicoder v2 help or some old way
    // that i'm not aware of. But since this is not crucial part, we can skip.

    // ------------------------ ADMIN ------------------------ //

    /// @notice create the collection pool 
    function setCollection(
        bool _isStakable,
        address _collectionAddress,
        uint256 _stakingFee,
        uint256 _harvestingFee,
        uint256 _multiplier,
        uint256 _maturityPeriod,
        uint256 _daysStakedMultiplier,
        uint256 _requiredDaysToMultiply
    ) public onlyOwner {
        nftCollection.push(
            NftCollection({
                isStakable: _isStakable,
                collectionAddress: _collectionAddress,
                stakingFee: _stakingFee,
                harvestingFee: _harvestingFee,
                multiplier: _multiplier,
                maturityPeriod: _maturityPeriod,
                amountOfStakers: 0,
                daysStakedMultiplier: _daysStakedMultiplier,
                requiredDaysToMultiply: _requiredDaysToMultiply
            })
        );
    }

    /// @notice update the collection pool
    /// @dev compiler weirdly thinks this should be the view funciton. Dont modify
    function updateCollection(
        uint256 _cid,
        bool _isStakable,
        address _collectionAddress,
        uint256 _stakingFee,
        uint256 _harvestingFee,
        uint256 _multiplier,
        uint256 _maturityPeriod,
        uint256 _daysStakedMultiplier,
        uint256 _requiredDaysToMultiply
    ) public onlyOwner {
        NftCollection memory collection = nftCollection[_cid];
        collection.isStakable = _isStakable;
        collection.collectionAddress = _collectionAddress;
        collection.stakingFee = _stakingFee;
        collection.harvestingFee = _harvestingFee;
        collection.multiplier = _multiplier;
        collection.maturityPeriod = _maturityPeriod;
        collection.daysStakedMultiplier = _daysStakedMultiplier;
        collection.requiredDaysToMultiply = _requiredDaysToMultiply;
    }
    /// @notice enable/disable staking in given pool
    /// @dev compiler weirdly thinks this should be the view funciton. Dont modify
    function manageCollection(uint256 _cid, bool _isStakable) public onlyOwner {
        NftCollection memory collection = nftCollection[_cid];
        collection.isStakable = _isStakable;
    }

    /// @dev compiler weirdly thinks this should be the pure funciton. Dont modify
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
