



const LLTH = artifacts.require("MockLLTH");
const Collection = artifacts.require("MockCollection");
const provableAPI = artifacts.require("usingProvable");
const Masterdemon = artifacts.require("Masterdemon");


const { duration, increaseTimeTo } = require('./utils');

var chai = require("./setupchai.js");
const BN = web3.utils.BN;
const expect = chai.expect;

const truffleAssert = require('truffle-assertions');
const { assert } = require('chai');



contract("Masterdemon - Orcale testing", async accounts => {
  

    beforeEach(async () => {

        llth = await LLTH.deployed();
        collection = await Collection.deployed();
        provable = await provableAPI.deployed();
        masterdemon = await Masterdemon.deployed(llth.address)

    });


    it('view amount', async () => {

        console.log((await masterdemon.viewAmountOfStakers(0)).toString()); // cid zero  // REVERTS

    })

    
    it('can record amountOfStakers in a pool after staking/unstaking', async () => {

        


        // _cid = 0
        await masterdemon.setCollection(
            true, // isStakable
            collection.address, // collectionAddress
            1, // stakingFee
            1, // harvestingFee
            2, // multiplier
            0, // maturityPeriod
            20, // stakingLimit
        );


        await collection.mint(1, accounts[1]);
        await collection.mint(1, accounts[2]);
        await collection.mint(1, accounts[3]);
        

        //await collection.approve(masterdemon.address, 0);
        await collection.setApprovalForAll(masterdemon.address, true, {from: accounts[1]});
        await collection.setApprovalForAll(masterdemon.address, true, {from: accounts[2]});
        await collection.setApprovalForAll(masterdemon.address, true, {from: accounts[3]});


        var numberOfStakers = await masterdemon.viewAmountOfStakers(0)
        assert.equal(numberOfStakers, 0)


        // stakes 1 token
        await masterdemon.stake(0, 0, { from: accounts[1] });
        expect(await collection.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(0));
        expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(1));
        var numberOfStakers = parseInt(await masterdemon.viewAmountOfStakers(0).toString())
        assert.equal(numberOfStakers, 1)


        // 2nd user stakes 1 token
        await masterdemon.stake(0, 1, { from: accounts[2] });
        expect(await collection.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(0));
        expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(2));
        var numberOfStakers = parseInt(await masterdemon.viewAmountOfStakers(0).toString())
        assert.equal(numberOfStakers, 2)


        // unstakes 1 token
        await masterdemon.unstake(0, 0, { from: accounts[1] });
        expect(await collection.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(1));
        expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(1));
        var numberOfStakers = parseInt(await masterdemon.viewAmountOfStakers(0).toString())
        assert.equal(numberOfStakers, 1)
   

    })
    
    
    // truffle test test/amountOfStakers_test.js --compile-none


    
    
})