/* TESTING ORACLE QUERIES ON LOCAL BLOCKCHAIN (https://github.com/provable-things/ethereum-bridge)


1. in new terminal: truffle dev (port 9545)
2. in new terminal: npm run bridge (port 9545 - changable in package.json)
3. paste OAR address in to constructor of Masterdemon.sol
4. in truffle(develop)> terminal [step 2] : truffle test

*/ 



const LLTH = artifacts.require("MockLLTH");
const Collection = artifacts.require("MockCollection");
const provableAPI = artifacts.require("usingProvable");
const Masterdemon = artifacts.require("Masterdemon");


const { waitForEvent } = require('./utils')
const { duration, increaseTimeTo, latestTime } = require('./utils');

var chai = require("./setupchai.js");
const BN = web3.utils.BN;
const expect = chai.expect;

const truffleAssert = require('truffle-assertions');
const { assert } = require('chai');



contract("Masterdemon - Staking/Unstaking basic, non-error testing", async accounts => {
  

    beforeEach(async () => {

        llth = await LLTH.new();
        collection = await Collection.new();
        provable = await provableAPI.new();
        masterdemon = await Masterdemon.new(llth.address)


        // _id = 0
        await collection.mint(3, accounts[0]);

        // _cid = 0
        await masterdemon.setCollection(
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


    
    it("[ Masterdemon, LLTH, Collection] Should deploy", async () => {
        assert(llth.address != '');
        assert(collection.address != '');
        assert(masterdemon.address != '');
    });

    it("[ Masterdemon ] Should Allow Single Staking", async () => {
        let amountStaked;
        await collection.setApprovalForAll(masterdemon.address, true);
        await masterdemon.stake(0, 0, { from: accounts[0] });
        await masterdemon.getUser(accounts[0], collection.address).then(res => {
            amountStaked = res['0'];
        });

        assert.equal(amountStaked.words[0], 1);
    });

    it("[ Masterdemon ] Should Allow Batch Staking", async () => {
        let amountStaked;
        await masterdemon.batchStake(0, [1, 2], { from: accounts[0] });
        await masterdemon.getUser(accounts[0], collection.address).then(res => {
            amountStaked = res['0'];
        });

        assert.equal(amountStaked.words[0], 3);
    });

    it("[ Masterdemon ] Should Allow Unstaking", async () => {
        let amountStaked;
        await masterdemon.unstake(0, 1, { from: accounts[0] });
        await masterdemon.getUser(accounts[0], collection.address).then(res => {
            amountStaked = res['0'];
        })

        assert.equal(amountStaked.words[0], 2);
    })
    

    
    /*
    it('Harvest stuff', async () => {
        

        expect(await collection.totalSupply()).to.be.a.bignumber.equal(new BN(3));
        expect(await collection.balanceOf(accounts[0])).to.be.a.bignumber.equal(new BN(3));

        //await collection.approve(masterdemon.address, 0);
        await collection.setApprovalForAll(masterdemon.address, true);

        // stakes 1 token
        await masterdemon.stake(0, 0, { from: accounts[0] });
        expect(await collection.balanceOf(accounts[0])).to.be.a.bignumber.equal(new BN(2));
        expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(1));

        await masterdemon.send(1e17); // sends smart contract ether to cover oracle fee

        expect(await llth.balanceOf(accounts[0])).to.be.a.bignumber.equal(new BN(0)); // LLTH balance should be zero

        // increases timestamp and therefore staking time by 1 day
        currentTimeStamp = (await web3.eth.getBlock('latest')).timestamp;
        const moveToDate = currentTimeStamp + duration.days(1);
        await increaseTimeTo(moveToDate);
        info = await masterdemon.getUser(accounts[0], collection.address)
        daysStaked = info[1].toString()
  
        assert.equal(parseInt(daysStaked), 1)

        
        await masterdemon.harvest(0);

        // need to wait for __callback() to be called by oracle
        function timeout(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }
    
        await timeout(10000);

        // reward = (multiplier*daysStaked*rarity)/numberOfStakers = (2*1*100)/1 = 200
        expect(await llth.balanceOf(accounts[0])).to.be.a.bignumber.equal(new BN(200));
        console.log((await llth.balanceOf(accounts[0])).toString());
        

    })
    */
    
})