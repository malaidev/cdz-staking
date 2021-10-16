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
        uint256 daysStaked;
        uint256[] tokenIds; // ids of nfts user staked
        mapping(uint256 => bool) tokenIdsMapping; // for checking if user really staked tokens
        mapping(uint256 => uint256) tokenIndex; // for delicate operations
    }

    struct NftCollection {
        // some dummy values
        bool isStakable;
        address collectionAddress;
        uint256 stakingFee;
        uint256 harvestingFee;
        uint256 withdrawingFee;
        uint256 normalizer;
        uint256 multiplier;
        uint256 maturityPeriod;
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

    function stake(uint256 _cid, uint256 _id) external {
        _stake(msg.sender, _cid, _id);
    }

    function unstake(uint256 _id, uint256 _cid) external {
        _unstake(msg.sender, _cid, _id);
    }

    function stakeBatch(uint256 _cid, uint256[] memory _ids) external {
        for (uint256 i = 0; i < _ids.length; ++i) {
            _stake(msg.sender, _cid, _ids[i]);
        }
    }

    function unstakeBatch(uint256[] memory _ids, uint256 _cid) external {
        for (uint256 i = 0; i < _ids.length; ++i) {
            _unstake(msg.sender, _cid, _ids[i]);
        }
    }

    function harvest(uint256 _cid, uint256 _id) external {
        _harvest(msg.sender, _cid, _id);
    }

    function batchHarvest(uint256 _cid, uint256[] memory _ids) external {
        for (uint256 i = 0; i < _ids.length; ++i) {
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
        require(
            IERC721(nftCollection[_cid].collectionAddress).ownerOf(_id) ==
                address(_user),
            "ERR: YOU DONT OWN THIS TOKEN"
        );
        IERC721(nftCollection[_cid].collectionAddress).safeTransferFrom(
            _user,
            address(this),
            _id
        );
        userInfo[_user].amountStaked = userInfo[_user].amountStaked.add(1);
        userInfo[_user].tokenIds.push(_id);
        userInfo[_user].tokenIdsMapping[_id] = true;

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
        require(
            userInfo[_user].tokenIdsMapping[_id] == true,
            "YOU DONT OWN THE TOKEN AT GIVEN INDEX"
        );
        IERC721(nftCollection[_cid].collectionAddress).safeTransferFrom(
            address(this),
            _user,
            _id
        );

        uint256 lastIndex = userInfo[_user].tokenIds.length - 1;
        uint256 lastIndexKey = userInfo[_user].tokenIds[lastIndex];
        uint256 tokenIdIndex = userInfo[_user].tokenIndex[_id];

        userInfo[_user].tokenIds[tokenIdIndex] = lastIndexKey;
        userInfo[_user].tokenIndex[lastIndexKey] = tokenIdIndex;
        if (userInfo[_user].tokenIds.length > 0) {
            userInfo[_user].tokenIds.pop();
            userInfo[_user].tokenIdsMapping[_id] = false;
            delete userInfo[_user].tokenIndex[_id];
            userInfo[_user].amountStaked -= 1;
        }

        if (userInfo[_user].amountStaked == 0) {
            delete userInfo[msg.sender];
        }

        emit UserUnstaked(_user);
    }

    function _harvest(address _user, uint256 _cid, uint256 _id) internal {
        NftCollection memory collection = nftCollection[_cid];
        UserInfo storage user = userInfo[_user];
        
        uint256 rarity = _getRarity(collection.collectionAddress, _id); 
        uint256 reward = _calculateRewards(rarity, collection.normalizer, 1, collection.multiplier, 100); // some dummy values

        user.currentReward = user.currentReward.sub(reward);
        user.daysStaked = 0;

        llth.transfer(_user, reward);
        emit UserHarvested(_user);
    }

    /// @notice dummy function, will be replaced by oracle later
    function _getRarity(address _collectionAddress, uint256 _id) internal pure returns (uint256) {
        return 40;
    }

    /// @notice will calculate rarity based on our formula
    /// @param _rarity number given my trait normalization formula
    /// @param _normalizer number that will range _rarity into normalized numbers range
    /// @param _daysStaked maturity period
    /// @param _multiplier pool can have multiplier
    /// @param _amountOfStakers used to minimize rewards proportionally to pool popularity
    function _calculateRewards(
        uint256 _rarity,
        uint256 _normalizer,
        uint256 _daysStaked,
        uint256 _multiplier,
        uint256 _amountOfStakers
    ) internal pure returns (uint256) {
        require(
            _rarity != 0 &&
                _daysStaked != 0 &&
                _multiplier != 0 &&
                _amountOfStakers != 0 &&
                _normalizer != 0,
            "CANT BE ZERO"
        );

        uint256 baseMultiplier = _multiplier.mul(_daysStaked);
        uint256 baseRarity = _normalizer.mul(_rarity);
        uint256 basemultiplierxRarity = baseMultiplier.mul(baseRarity);
        uint256 finalReward = basemultiplierxRarity.div(_amountOfStakers);

        return finalReward;
    }

    // ------------------------ GET for frontend ------------------------ //

    function getCollectionInfo(uint256 _cid)
        public
        view
        returns (NftCollection memory)
    {
        NftCollection memory collection = nftCollection[_cid];
        return collection;
    }

    // returning UserInfo is other story, since it contains nested mapping
    // compiler will throw an error that due to this, struct is sitting in storage
    // but returning a struct can only accept either memory or calldata
    // this needs to be fixed either with abicoder v2 help or some old way
    // that i'm not aware of. But since this is not crucial part, we can skip.

    // ------------------------ ADMIN ------------------------ //

    function setCollection(
        bool _isStakable,
        address _collectionAddress,
        uint256 _stakingFee,
        uint256 _harvestingFee,
        uint256 _withdrawingFee,
        uint256 _normalizer,
        uint256 _multiplier,
        uint256 _maturityPeriod
    ) public onlyOwner {
        nftCollection.push(
            NftCollection({
                isStakable: _isStakable,
                collectionAddress: _collectionAddress,
                stakingFee: _stakingFee,
                harvestingFee: _harvestingFee,
                withdrawingFee: _withdrawingFee,
                normalizer: _normalizer,
                multiplier: _multiplier,
                maturityPeriod: _maturityPeriod
            })
        );
    }

    function updateCollection(
        uint256 _cid,
        bool _isStakable,
        address _collectionAddress,
        uint256 _stakingFee,
        uint256 _harvestingFee,
        uint256 _withdrawingFee,
        uint256 _normalizer,
        uint256 _multiplier,
        uint256 _maturityPeriod
    ) public onlyOwner {
        nftCollection[_cid].isStakable = _isStakable;
        nftCollection[_cid].collectionAddress = _collectionAddress;
        nftCollection[_cid].stakingFee = _stakingFee;
        nftCollection[_cid].harvestingFee = _harvestingFee;
        nftCollection[_cid].withdrawingFee = _withdrawingFee;
        nftCollection[_cid].normalizer = _normalizer;
        nftCollection[_cid].multiplier = _multiplier;
    }

    function manageCollection(uint256 _cid, bool _isStakable) public onlyOwner {
        nftCollection[_cid].isStakable = _isStakable;
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
