const LLTH = artifacts.require('MockLLTH');
const Collection = artifacts.require('MockCollection');
const Masterdemon = artifacts.require('Masterdemon');

const truffleAssert = require('truffle-assertions');

contract(
  'Masterdemon - Staking/Unstaking basic, non-error testing',
  async (accounts) => {
    let llth;
    let collection;
    let masterdemon;

    beforeEach(async () => {
      llth = await LLTH.new();
      collection = await Collection.new();
      masterdemon = await Masterdemon.new(llth.address)

      // _id = 0
      collection.mint(4, accounts[0]);

      // _cid = 0
      masterdemon.setCollection(
        true, // isStakable
        collection.address, // collectionAddress
        1, // stakingFee
        1, // harvestingFee
        2, // multiplier
        0, // maturityPeriod
        20, // maxDaysForStaking
        20, // stakingLimit
      );
    });

    it('[ Masterdemon, LLTH, Collection] Should deploy', async () => {
      assert(llth.address != '');
      assert(collection.address != '');
      assert(masterdemon.address != '');
    });

    it('[ Masterdemon ] Should Allow Single Staking', async () => {
      let amountStaked;
      await collection.setApprovalForAll(masterdemon.address, true);
      await masterdemon.stake(0, 0, { from: accounts[0] });
      await masterdemon.getUser(accounts[0], collection.address).then((res) => {
        amountStaked = res['0'];
      });

      assert.equal(amountStaked.words[0], 1);
    });

    it('[ Masterdemon ] Should Allow Batch Staking', async () => {
      let amountStaked;
      await collection.setApprovalForAll(masterdemon.address, true);
      await masterdemon.batchStake(0, [1, 2, 3], { from: accounts[0] });
      await masterdemon.getUser(accounts[0], collection.address).then((res) => {
        amountStaked = res['0'];
      });

      assert.equal(amountStaked.words[0], 4);
    });

    it('[ Masterdemon ] Should Allow Unstaking', async () => {
      let amountStaked;
      await collection.setApprovalForAll(masterdemon.address, true);
      await masterdemon.stake(0, 0, { from: accounts[0] });
      await masterdemon.unstake(0, 0, { from: accounts[0] });
      await masterdemon.getUser(accounts[0], collection.address).then((res) => {
        amountStaked = res['0'];
      });

      assert.equal(amountStaked.words[0], 0);
    });

    it('[ Masterdemon ] Should Allow Batch Unstaking', async () => {
      let amountStaked;
      await collection.setApprovalForAll(masterdemon.address, true);
      await masterdemon.batchStake(0, [1, 2, 3], { from: accounts[0] });
      await masterdemon.batchUnstake(0, [1, 2, 3], { from: accounts[0] });
      await masterdemon.getUser(accounts[0], collection.address).then((res) => {
        amountStaked = res['0'];
      });

      assert.equal(amountStaked.words[0], 0);
    });
  },
);

contract(
  'Masterdemon => Staking/Unstaking advanced, error testing',
  async (accounts) => {
    let llth;
    let collection;
    let masterdemon;

    beforeEach(async () => {
      llth = await LLTH.deployed();
      collection = await Collection.deployed();
      masterdemon = await Masterdemon.deployed();

      // _id = 0
      collection.mint(1, accounts[0]);
      collection.mint(1, accounts[1]);

      // _cid = 0
      masterdemon.setCollection(
        true, // isStakable
        collection.address, // collectionAddress
        1, // stakingFee
        1, // harvestingFee
        2, // multiplier
        0, // maturityPeriod
        20, // maxDaysForStaking
        20, // stakingLimit
      );
    });

    it(" [ Masterdemon advanced ] Shouldn't Unstake For Non-Owner", async () => {
      await collection.setApprovalForAll(masterdemon.address, true);
      await masterdemon.stake(0, 0, { from: accounts[0] });

      await truffleAssert.fails(
        masterdemon.unstake(0, 0, { from: accounts[1] }),
        truffleAssert.ErrorType.REVERT,
        "Masterdemon._unstake: Sender doesn't owns this token",
      );
    });


    it(' [ Masterdemon advanced ] Should Calculate amountOfStakers Correctly', async () => {
        let amountOfStakers;

        await masterdemon.unstake(0, 0, { from: accounts[0] });
        //await masterdemon.getCollectionInfo(0).then(res => {
        //  console.log(res)
        //})

    });
  },
);
