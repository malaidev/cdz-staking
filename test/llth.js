/***************************************** DUE TO NEW CONTRACT ALL TESTS ARE USELESS, DO NOT USE *****************************************/
/***************************************** DO NOT DELETE EITHER. GOOD REFERENCE FOR NEW TESTS *****************************************/

const MockLLTH = artifacts.require("MockLLTH");
const MockCollection = artifacts.require("MockCollection");

const MasterDemon = artifacts.require("Masterdemon");

const { duration, increaseTimeTo } = require('./utils');
const { ethers } = require("ethers");

const { BN } = web3.utils;

const truffleAssert = require('truffle-assertions');

contract("MockLLTH", async accounts => {
  let currentTimeStamp;
  let collection;
  let llth;
  let masterDemon;

  let stakedTimeStamp;

  beforeEach(async function () {
    llth = await MockLLTH.deployed();
    collection = await MockCollection.deployed();
    masterDemon = await MasterDemon.deployed();
  });

  it("[ MockLLTH ] should mint LLTH", async () => {
    const amount = ethers.BigNumber.from(1000000).mul(ethers.constants.WeiPerEther);
    const mintBalance = await llth.balanceOf.call(accounts[0]);
    assert.equal(mintBalance, 1000000*10**18);

    // transfer all minted llth to masterDemon contract for distributing the farming rewards.
    await llth.transfer(masterDemon.address, amount);

  });

  it("[ MasterDemon ] should minting 1 nft to account[0]", async () => {
    await collection.mint(1);
    const mintNFTBalance = await collection.balanceOf.call(accounts[0]);
    assert.equal(mintNFTBalance, 1);
  });
  
  it("[ MasterDemon ] staking nft 0 of account[0] to staking contract", async () => {

    // set NFT collection, collection id will be 0
    currentTimeStamp = (await web3.eth.getBlock('latest')).timestamp;
    await masterDemon.setCollection(true, collection.address, 0, 0, 1, 1, 1, 2, currentTimeStamp + duration.weeks(10));

    // stake with Params cid: 0, nftId: 0
    await collection.approve(masterDemon.address, 0);
    await masterDemon.stake(0, 0);

    // get staked amount of nft in MasterDemon contract
    const amountNftStaked = await collection.balanceOf.call(masterDemon.address);
    assert.equal(amountNftStaked, 1, "NFT wasn't staked to MasterDemon Contract");

    let userInfo = await masterDemon.returnUserInfo(accounts[0]);
    stakedTimeStamp = userInfo[0];

  });
  
  // booster: 1, daysStaked: 30, rarity*normalizer: 100, poolSize: 200 ==> reward should be 15
  it("[ MasterDemon ] harvesting, should send reward 15 LLTH", async () => {
    const moveToDate = stakedTimeStamp.toNumber() + duration.days(30);
    await increaseTimeTo(moveToDate);

    const result = await masterDemon.harvest(0);
    truffleAssert.eventEmitted(result, 'UserHarvested', (ev) => {
      return ev.reward == 15;
    });

    const balanceLLTH = await llth.balanceOf(accounts[0]);
    // console.log("balance after harvest: ", balanceLLTH.toString());
    assert.equal(balanceLLTH, 15);
  });

  it("[ MasterDemon ] unstaking nft 0 of staking contract to account[0]", async () => {
    // unstake with Params cid: 0, nftId: 0
    await masterDemon.unstake(0, 0);

    // get staked amount of nft in MasterDemon contract
    const amountNftStaked = await collection.balanceOf.call(masterDemon.address);
    assert.equal(amountNftStaked, 0, "NFT wasn't unstaked from MasterDemon contract");
  });

});