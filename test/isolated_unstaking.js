const LLTH = artifacts.require('MockLLTH');
const Collection = artifacts.require('MockCollection');
const Masterdemon = artifacts.require('Masterdemon');


const truffleAssert = require('truffle-assertions');

var chai = require("./setupchai.js");
const BN = web3.utils.BN;
const expect = chai.expect;


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
      collection.mint(3, accounts[0]);

      // _cid = 0
      masterdemon.setCollection(
        true, // isStakable
        collection.address, // collectionAddress
        1, // stakingFee
        1, // harvestingFee
        2, // multiplier
        0, // maturityPeriod
        20, // stakingLimit
      );
    });

    it('unstaking check', async () => {
      await collection.setApprovalForAll(masterdemon.address, true);
      await masterdemon.batchStake(0, [0, 1, 2], { from: accounts[0] });
      expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(3));
      //await masterdemon.batchUnstake(0, [0, 1], { from: accounts[0] });
      await masterdemon.batchUnstake(0, [0, 1, 2], { from: accounts[0] });
      expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(0));
      //await masterdemon.unstake(0, 2, { from: accounts[0] });
    }); 
  },
);
