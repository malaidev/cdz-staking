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
import "./libs/Array.sol";

contract Masterdemon is Ownable, ReentrancyGuard {
    using Address for address;
    using Array for uint256[];

    /**
     *    @notice keep track of each user and their info
     */
    struct UserInfo {
        mapping(address => uint256[]) stakedTokens;
        mapping(address => uint256) timeStaked;
        uint256 amountStaked;
    }

    /**
     *    @notice keep track of each collection and their info
     */
    struct CollectionInfo {
        bool isStakable;
        address collectionAddress;
        uint256 stakingFee;
        uint256 harvestingFee;
        uint256 multiplier;
        uint256 amountOfStakers;
        uint256 stakingLimit;
        uint256 harvestCooldown;
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
     *   @notice array of each collection, we search through this by _cid (collection identifier)
     */
    CollectionInfo[] public collectionInfo;

    constructor() {}

    /*-------------------------------Main external functions-------------------------------*/

    /**
     *   @notice external stake function, for single stake request
     *   @param _cid => collection address
     *   @param _id => nft id
     */
    function stake(uint256 _cid, uint256 _id) external payable {
        require(
            msg.value >= collectionInfo[_cid].stakingFee,
            "Masterdemon.stake: Fee"
        );
        _stake(msg.sender, _cid, _id);
    }

    /**
     *   @notice loops normal stake, in case of multiple stake requests
     *   @param _cid => collection address
     *   @param _ids => array of nft ids
     */
    function batchStake(uint256 _cid, uint256[] memory _ids) external payable {
        for (uint256 i = 0; i < _ids.length; ++i) {
            require(
                msg.value >= collectionInfo[_cid].stakingFee,
                "Masterdemon.stake: Fee"
            );
            _stake(msg.sender, _cid, _ids[i]);
        }
    }

    /**
     *   @notice external unstake function, for single unstake request
     *   @param _cid => collection address
     *   @param _id => nft id
     */
    function unstake(uint256 _cid, uint256 _id) external {
        _unstake(msg.sender, _cid, _id);
    }

    /**
     *   @notice loops normal unstake, in case of multiple unstake requests
     *   @param _cid => collection address
     *   @param _ids => array of nft ids
     */
    function batchUnstake(uint256 _cid, uint256[] memory _ids) external {
        for (uint256 i = 0; i < _ids.length; ++i) {
            _unstake(msg.sender, _cid, _ids[i]);
        }
    }

    /*-------------------------------Main internal functions-------------------------------*/

    /**
     *    @notice internal stake function, called in external stake and batchStake
     *    @param _user => msg.sender
     *    @param _cid => collection id
     *    @param _id => nft id
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
     *    @param _cid => collection id
     *    @param _id => nft id
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

        delete tokenOwners[collection.collectionAddress][_id];

        user.timeStaked[collection.collectionAddress] = 0;
        user.amountStaked -= 1;

        if (user.amountStaked == 0) {
            delete userInfo[_user];
        }
    }

    /*-------------------------------Admin functions-------------------------------*/

    /**
     *    @notice initialize new collection
     *    @param _isStakable => is pool active?
     *    @param _collectionAddress => address of nft collection
     *    @param _stakingFee => represented in WEI
     *    @param _harvestingFee => represented in WEI
     *    @param _multiplier => special variable to adjust returns
     *    @param _stakingLimit => total amount of nfts user is allowed to stake
     *    @param _harvestCooldown => represented in days
     */
    function setCollection(
        bool _isStakable,
        address _collectionAddress,
        uint256 _stakingFee,
        uint256 _harvestingFee,
        uint256 _multiplier,
        uint256 _stakingLimit,
        uint256 _harvestCooldown
    ) public onlyOwner {
        collectionInfo.push(
            CollectionInfo({
                isStakable: _isStakable,
                collectionAddress: _collectionAddress,
                stakingFee: _stakingFee,
                harvestingFee: _harvestingFee,
                multiplier: _multiplier,
                amountOfStakers: 0,
                stakingLimit: _stakingLimit,
                harvestCooldown: _harvestCooldown
            })
        );
    }

    /**
     *    @notice update collection
     *    {see above function for param definition}
     */
    function updateCollection(
        uint256 _cid,
        bool _isStakable,
        address _collectionAddress,
        uint256 _stakingFee,
        uint256 _harvestingFee,
        uint256 _multiplier,
        uint256 _stakingLimit,
        uint256 _harvestCooldown
    ) public onlyOwner {
        CollectionInfo storage collection = collectionInfo[_cid];
        collection.isStakable = _isStakable;
        collection.collectionAddress = _collectionAddress;
        collection.stakingFee = _stakingFee;
        collection.harvestingFee = _harvestingFee;
        collection.multiplier = _multiplier;
        collection.stakingLimit = _stakingLimit;
        collection.harvestCooldown = _harvestCooldown;
    }

    /**
     *    @notice enable/disable collections, without updating whole struct
     *    @param _cid => collection id
     *    @param _isStakable => enable/disable
     */
    function manageCollection(uint256 _cid, bool _isStakable) public onlyOwner {
        collectionInfo[_cid].isStakable = _isStakable;
    }

    /*-------------------------------Get functions for frontend-------------------------------*/

    function getUserInfo(address _user, address _collection)
        public
        view
        returns (
            uint256[] memory,
            uint256,
            uint256
        )
    {
        UserInfo storage user = userInfo[_user];
        return (
            user.stakedTokens[_collection],
            user.timeStaked[_collection],
            user.amountStaked,

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
            uint256,
            uint256
        )
    {
        CollectionInfo memory collection = collectionInfo[_cid];
        return (
            collection.isStakable,
            collection.collectionAddress,
            collection.stakingFee,
            collection.harvestingFee,
            collection.multiplier,
            collection.amountOfStakers,
            collection.stakingLimit,
            collection.harvestCooldown
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
