pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//TODO reward system
//TODO reward token
//TODO rarity calculator


contract Masterdemon is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;

    // do we really need to keep track of each NFT???
    /*
    struct NftInfo {
        uint256 rarity; // rarity to calculate reward minting strategy
        uint256 stakeFee; // entry fee (might be 0)
        uint256 withdrawFee; // exit fee (might be 0)
        uint256 booster; // each nft will have rewards booster
    }
    */

    struct UserInfo {
        uint256 amountStaked; // how many nfts did user staked
        uint256[] tokenIds;   // ids of nfts user staked
        mapping (uint256 => uint256) tokenIndex;
    }

    // @notice id => each nft
   //mapping(uint256 => NftInfo) public nftInfo;

    /// @notice address => each user
    mapping(address => UserInfo) public userInfo;

    /// @notice cryptodemonz v1 official address
    address public demonz = 0xAE16529eD90FAfc927D774Ea7bE1b95D826664E3;

    /// @notice LLTH address
    IERC20 public rewardsToken;

    /// @notice fee for staking
    uint256 stakingFee = 0.06 ether;

    /// @notice fee for withdrawing 
    uint256 withdrawFee = 0.08 ether;

    event UserStaked(address staker);
    //TODO amount
    event UserUnstaked(address unstaker);

   
     // ------------------------ PUBLIC/EXTERNAL ------------------------ //

    constructor( 
        IERC20 _rewardsToken
    ) public {
        rewardsToken = _rewardsToken;
    }

    function stake(uint256 _id) external {
        _stake(msg.sender, _id);
    } 

    function unstake(uint256 _id) external {
        _unstake(msg.sender, _id);
    }

    function stakeBatch(uint256[] memory _ids) external {
        for (uint256 i=0; i<_ids.length; ++i) {
            _stake(msg.sender, _ids[i]);
        }
    }

    function unstakeBatch(uint256[] memory _ids) external {
        for (uint256 i=0; i<_ids.length; ++i) {
            _unstake(msg.sender, _ids[i]);
        }
    }

    // ------------------------ INTERNAL ------------------------ //

    /// @notice stake single nft (called in external function)
    /// @param _user = msg.sender
    /// @param _id = nft id
    function _stake(address _user, uint256 _id) internal {
        require(msg.value >= stakingFee, "ERR: FEE NOT COVERED");
        require(IERC721(demonz).ownerOf(_id) == address(_user), "ERR: YOU DONT OWN THIS TOKEN");
        IERC721(demonz).safeTransferFrom(_user, address(this), _id);

        UserInfo storage user = userInfo[_user];
        user.amountStaked = user.amountStaked.add(1);
        user.tokenIds.push(_id);

        emit UserStaked(_user);
    } 

    /// @notice unstake single nft (called in external function)
    /// @param _user = msg.sender
    /// @param _id = nft id
    function _unstake(address _user, uint256 _id) internal {
        require(msg.value >= stakingFee, "ERR: FEE NOT COVERED");
        require(IERC721(demonz).ownerOf(_id) == address(_user), "ERR: YOU DONT OWN THIS TOKEN");

        UserInfo storage user = userInfo[_user];
        IERC721(demonz).safeTransferFrom(address(this), _user, _id);

        uint256 lastIndex = user.tokenIds.length - 1;
        uint256 lastIndexKey = user.tokenIds[lastIndex];
        uint256 tokenIdIndex = user.tokenIndex[_id];

        user.tokenIds[tokenIdIndex] = lastIndexKey;
        user.tokenIndex[lastIndexKey] = tokenIdIndex;
        if (user.tokenIds.length > 0) {
            user.tokenIds.pop();
            delete user.tokenIndex[_id];
            user.amountStaked -= 1;
            }

        if (user.amountStaked == 0) {
            delete userInfo[msg.sender];
        }

    }

    // ------------------------ DEV ------------------------ //

    function changeStakingFee(uint256 _staking) public onlyOwner() {
        require(stakingFee != _staking, "DEV_ERR: VALUE ALREADY SET");
        stakingFee = _staking;
    }

    function changeUnstakingFee(uint256 _unstaking) public onlyOwner() {
        require(withdrawFee != _unstaking, "DEV_ERR: VALUE ALREADY SET");
        withdrawFee = _unstaking;
    }

    function changeDemonzAddress(address _newAddress) public onlyOwner() {
        require(demonz != _newAddress, "DEV_ERR: ADDRESS ALREADY SET");
        demonz = _newAddress;
    }

    /// @notice Get the tokens staked by a user
    /// @param _user address of user
    function getStakedTokens(address _user) external view returns (uint256[] memory tokenIds) {

        return userInfo[_user].tokenIds;
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
