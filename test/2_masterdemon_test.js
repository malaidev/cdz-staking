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
        masterdemon = await Masterdemon.deployed()

    });


    
    it('Can harvest a single token', async () => {

        await masterdemon.send(1e18); // sends smart contract ether to cover oracle fee

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

        await collection.mint(3, accounts[1]);
        
        expect(await collection.totalSupply()).to.be.a.bignumber.equal(new BN(3));
        expect(await collection.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(3));

        //await collection.approve(masterdemon.address, 0);
        await collection.setApprovalForAll(masterdemon.address, true, {from: accounts[1]});

        // stakes 1 token
        await masterdemon.stake(0, 0, { from: accounts[1] });
        expect(await collection.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(2));
        expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(1));


        console.log((await masterdemon.viewAmountOfStakers(0)).toString()); 


        expect(await llth.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(0)); // LLTH balance should be zero

        // increases block.timestamp and therefore staking time by 1 day
        currentTimeStamp = (await web3.eth.getBlock('latest')).timestamp;
        var moveToDate = currentTimeStamp + duration.days(1);
        await increaseTimeTo(moveToDate);

        await masterdemon.harvest(0, {from: accounts[1]});

        // need to wait for __callback() to be called by oracle
        function timeout(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }
        await timeout(15000); 

        // reward = (multiplier*daysStaked*rarity)/numberOfStakers = (2*1*100)/1 = 200
        expect(await llth.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(200)); // LLTH balance should = reward
        

    })

    
    it('Can harvest again later', async () => {

        expect(await collection.totalSupply()).to.be.a.bignumber.equal(new BN(3));
        expect(await collection.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(2));
        expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(1));
        expect(await llth.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(200));

        // increases timestamp and therefore staking time by 4 days
        currentTimeStamp = (await web3.eth.getBlock('latest')).timestamp;
        var moveToDate = currentTimeStamp + duration.days(4);
        await increaseTimeTo(moveToDate);

        await masterdemon.harvest(0, {from: accounts[1]});

        // need to wait for __callback() to be called by oracle
        function timeout(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }
        await timeout(15000);

        // reward = 200 from previous harvest + 800 = 1000
        expect(await llth.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(1000));

    })


    it('Staking another token resets daysStaked', async () => {

        // increases timestamp and therefore staking time by 2 days
        currentTimeStamp = (await web3.eth.getBlock('latest')).timestamp;
        var moveToDate = currentTimeStamp + duration.days(2);
        await increaseTimeTo(moveToDate);
        

        // stakes another token
        await masterdemon.stake(0, 1, { from: accounts[1] });
        expect(await collection.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(1));
        expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(2));

        // increases block.timestamp and therefore staking time by 1 day
        currentTimeStamp = (await web3.eth.getBlock('latest')).timestamp;
        var moveToDate = currentTimeStamp + duration.days(1);
        await increaseTimeTo(moveToDate);

        await masterdemon.harvest(0, {from: accounts[1]});

        // need to wait for __callback() to be called by oracle
        function timeout(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }
        await timeout(15000);

        // reward = 1000 from previous harvests + (1 day * 2 tokens) @ 200 per token per day = 1400
        expect(await llth.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(1400));

    })
    
    
    
    it('Can batch harvest multiple tokens', async () => { 


        await collection.mint(3, accounts[2]);
        
        expect(await collection.totalSupply()).to.be.a.bignumber.equal(new BN(6));
        expect(await collection.balanceOf(accounts[2])).to.be.a.bignumber.equal(new BN(3));

        //await collection.approve(masterdemon.address, 0);
        await collection.setApprovalForAll(masterdemon.address, true, {from: accounts[2]});

        // stakes all 3 tokens
        await masterdemon.batchStake(0, [3, 4, 5], { from: accounts[2] });
        expect(await collection.balanceOf(accounts[2])).to.be.a.bignumber.equal(new BN(0));
        expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(5)); // 2 staked token from accounts[1] and 3 from accounts[2]


        //console.log((await masterdemon.getCollectionInfo(0)).toString()); // amountOfStakers should be 2 (accounts[1] and accounts[2])


        expect(await llth.balanceOf(accounts[2])).to.be.a.bignumber.equal(new BN(0)); // LLTH balance should be zero

        // increases block.timestamp and therefore staking time by 2 days
        currentTimeStamp = (await web3.eth.getBlock('latest')).timestamp;
        const moveToDate = currentTimeStamp + duration.days(2);
        await increaseTimeTo(moveToDate);
        
        await masterdemon.harvest(0, {from: accounts[2]});

        // need to wait for __callback() to be called by oracle
        function timeout(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }
        await timeout(30000); 

        // reward = 200 per token per day => (3 tokens * 2 days * 200) / 2 stakers in pool = 600
        expect(await llth.balanceOf(accounts[2])).to.be.a.bignumber.equal(new BN(600));

    })

    it('amountStakedInPool updates', async () => { 


        await collection.mint(1, accounts[7]);
        
        expect(await collection.totalSupply()).to.be.a.bignumber.equal(new BN(7));
        expect(await collection.balanceOf(accounts[7])).to.be.a.bignumber.equal(new BN(1));

        //await collection.approve(masterdemon.address, 0);
        await collection.setApprovalForAll(masterdemon.address, true, {from: accounts[7]});

        // stakes all 3 tokens
        await masterdemon.stake(0, 6, { from: accounts[7] });
        expect(await collection.balanceOf(accounts[7])).to.be.a.bignumber.equal(new BN(0));
        expect(await collection.balanceOf(masterdemon.address)).to.be.a.bignumber.equal(new BN(6)); // 2 staked token from accounts[1], 3 from accounts[2], 1 from accounts[7]


        //console.log((await masterdemon.getCollectionInfo(0)).toString()); // amountOfStakers should be 3 (accounts[1], accounts[2] and accounts[7])


        expect(await llth.balanceOf(accounts[7])).to.be.a.bignumber.equal(new BN(0)); // LLTH balance should be zero

        // increases block.timestamp and therefore staking time by 6 days
        currentTimeStamp = (await web3.eth.getBlock('latest')).timestamp;
        const moveToDate = currentTimeStamp + duration.days(6);
        await increaseTimeTo(moveToDate);
        
        await masterdemon.harvest(0, {from: accounts[7]});

        // need to wait for __callback() to be called by oracle
        function timeout(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }
        await timeout(15000); 

        // reward = 200 per token per day => (1 token * 6 days * 200) / 3 stakers in pool = 400
        expect(await llth.balanceOf(accounts[7])).to.be.a.bignumber.equal(new BN(400));

    })
    


    // truffle test test/2_masterdemon_test.js --compile-none


    // use listen for event rather than timeouts to save time when running test
    
})