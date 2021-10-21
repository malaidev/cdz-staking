# Masterdemon documentation
*author: kaneda*

## UserInfo
struct UserInfo {
        uint256 amountStaked; 
        uint256 daysStaked; 
        uint256[] tokenIds; 
        mapping(uint256 => uint256) tokenIndex; 
        mapping(address => mapping (uint256 => bool)) stakedInPools; 
    }

Used to track each user and their info. 
amountStaked: how many nfts did user staked in every pool
daysStaked: unix epoch / 60 / 60 / 24, representing the days
tokenIds: staked nft ids, for delicate operations
tokenIndex: for delicate operations
stakedInPools: double mapping checks if user really staked given nft in given pool

## NftCollection
struct NftCollection {
        bool isStakable; 
        address collectionAddress; 
        uint256 stakingFee; 
        uint256 harvestingFee; 
        uint256 multiplier; 
        uint256 maturityPeriod; 
        uint256 amountOfStakers; 
        uint256 daysStakedMultiplier; 
        uint256 requiredDaysToMultiply; 
    }

Used to track each collection and their info.
isStakable: enable/disable pools, we do this instead of deleting them from array
collectionAddress: ethereum address of each collection contract
stakingFee: paid in ETH
harvestingFee: paid in ETH
multiplier: boost rewards
maturityPeriod: counted in days, user will receive rewards after given period
amountOfStakers: how many stakers are in given collection
daysStakedMultiplier: we propose reward boosts after some period of staking
requiredDaystoMultiply: "some period"

## stake
function stake(uint256 _cid, uint256 _id) external payable {
        NftCollection memory collection = nftCollection[_cid];
        if (collection.stakingFee != 0) {
            require(msg.value == collection.stakingFee, "FEE NOT COVERED");
        }
        _stake(msg.sender, _cid, _id);
    }

External function that calls internal _stake. Just for clean code. All tho, fee collection
happens here.

## unstake
function unstake(uint256 _id, uint256 _cid) external {
        _unstake(msg.sender, _cid, _id);
    }

External function that calls internal _unstake. Just for clean code.

## stakeBatch
function stakeBatch(uint256 _cid, uint256[] memory _ids) external payable {
        NftCollection memory collection = nftCollection[_cid];
        for (uint256 i = 0; i < _ids.length; ++i) {
            if (collection.stakingFee != 0) {
                require(msg.value == collection.stakingFee, "FEE NOT COVERED");
            }
            _stake(msg.sender, _cid, _ids[i]);
        }
    }

External function, loops thru given _ids array and calls internal _stake. Just for clean code.

## unstakeBatch
function unstakeBatch(uint256[] memory _ids, uint256 _cid) external {
        for (uint256 i = 0; i < _ids.length; ++i) {
            _unstake(msg.sender, _cid, _ids[i]);
        }
    }

Well, you get the point. We wont cover harvest.

## _stake
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

        if (user.amountStaked == 0) {
            collection.amountOfStakers+=1;
        }
        user.amountStaked+=1;
        user.tokenIds.push(_id);
        user.daysStaked = block.timestamp;
        user.stakedInPools[collection.collectionAddress][_id] = true;

        emit UserStaked(_user);
    }

_stake takes 3 parameters, _user (msg.sender), _cid (collection id) and _id (nft id).

Then we call NftCollection struct from nftCollection array at given _cid index.

Require statement just assures that user is sending correct nft id, but i'm pretty positive
there is no need for this.

We call safeTransferFrom that takes msg.sender, and sends _id to this contract.

Then we increment amountOfStakers. To avoid incrementing it every time same user stakes, we make 
sure that user never staked in this collection pool before.

amountStaked gets incremented, we also push _id into tokenIds array, on third line we initialize 
the block.timestamp to start counting daysStaked and in last line, double mapping is used,
we say that user really staked given _id in given collectionAddress. This will be crucial part to
assure that in _unstake function, user wont grab others ids.

And then we emit the event.

## _unstake
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

        uint256 lastIndex = user.tokenIds.length.sub(1);
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

_unstake takes 3 parameters, _user (msg.sender), _cid (collection id) and _id (nft id).

To make sure that user truly staked given _id in given _cid, we use double mapping:
user.stakedInPools[collection.collectionAddress][_id] == true 

Then with safeTransferFrom, we send given _id to user.

LastIndexc, lastIndexKey and tokenIdIndex are needed to correctly calculate
how many tokens did user staked.

If user still has nfts staked in pool, we just make sure that in double mapping
given _cid => _id is set to false.

user.dayStaked = 0 even if user just unstakes one single nft.

If user has nothing staked then we remove them from amountOfStakers.

## _harvest
function _harvest(
        address _user,
        uint256 _cid,
    ) internal {
        NftCollection memory collection = nftCollection[_cid];
        UserInfo storage user = userInfo[_user];
        uint256 daysStaked = block.timestamp.sub(user.daysStaked) / 60 / 60 / 24;
        require(daysStaked <= collection.maturityPeriod, "YOU CANT HARVEST YET");
        require(collection.isStakable == true, "STAKING HAS FINISHED");
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

        llth.transfer(_user, reward);
        emit UserHarvested(_user);
    }

As you've noticed, we dont distribute rewards when unstaking, but rather while user clicks on harvest.

First of all, we calculate daysStaked by subtracting the block.timestamp from when user staked to actual block.timestmap,
and since it is in unix epoch time, we have to divide on 60 / 60 / 24 to extract days.

In following require statements, we check if maturityPeriod is enought for user to harvest rewards, and
is collection stakable at all.

Then from oracle, we get rarity of given _id, but since we avoided floats in code and normalizing the rarity
will happen on oracle side so we make sure that it is between our standard range 50 and 350.

Then we plug everything into _calculateRewards function that returns how much LLTH should user get.

dayStakedMultiplier and requiredDaysToMultiply is new concept we added, it will multiply reward by
daysStakedMultiplier after some requiredDaysToMultiply, calculated in days. for example 2x after 30 days of staking.
If statement just checks if daysStakedMultiplier is allowed for given pool and if yes, did user staked for required days.

And then we transfer rewards to user.


## _getRarity
function _getRarity(address _collectionAddress, uint256 _id)
        internal
        pure
        returns (uint256)
    {
        uint256 rarity = 100;
        return rarity;
    }

Dummy function, will be replaced by proper oracle call. Returns number between 50 and 350 representing the rarity
of the nft based on its traits. We calculate this with traits normalization.


