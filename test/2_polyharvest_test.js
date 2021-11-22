

const LLTH = artifacts.require("MockLLTH");


const Harvest = artifacts.require("Harvest");


const { duration, increaseTimeTo } = require('./utils');

var chai = require("./setupchai.js");
const BN = web3.utils.BN;
const expect = chai.expect;

const truffleAssert = require('truffle-assertions');
const { assert } = require('chai');

const LinkHelper = require('LinkHelper')

function epoch() {
    return Math.round(Date.now() / 1000);
}

function timeout(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

contract("Harvest - Polygon", async accounts => {
  

    beforeEach(async () => {

        llth = await LLTH.deployed();
        harvest = await Harvest.deployed()
        link = await LinkHelper.deployed()

    });


    
    it('Can harvest a single token when sole staker in pool', async () => {

        // sends smart contract LINK to cover oracle fee
        await link.approveLink(link.address, web3.utils.toWei('0.01', 'ether'));
        await link.sendLink(harvest.address, web3.utils.toWei('0.01', 'ether'));
        console.log(await harvest.viewLinkBalance())
        expect(await harvest.viewLinkBalance()).to.be.a.bignumber.equal(new BN(1e16)); // LLTH balance should be zero

        await harvest.setData(
            [1], // list of tokenId's
            (epoch() - (24*60*60)), // 1 day staked
            1, // multiplier
            1, // amountOfStakers
            accounts[0], // user address
            accounts[1], // collection address
            true
        );

        expect(await llth.balanceOf(accounts[0])).to.be.a.bignumber.equal(new BN(0)); // LLTH balance should be zero

        await harvest.harvest(accounts[1]); // (collection address)

        // need to wait for _fulfill() to be called by oracle
        await timeout(1000); 

        // reward = (multiplier*daysStaked*rarity)/numberOfStakers = (1*1*100)/1 = 100
        expect(await llth.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(100)); // LLTH balance should = reward
    });

    /*
    it('Can harvest multiple tokens from pool containing multiple stakers', async () => {

        // sends smart contract LINK to cover oracle fee
        await link.transfer(harvest.address, web3.utils.toWei('0.03', 'ether'));

        await harvest.setData(
            [1, 3, 6], // list of tokenId's
            (epoch() - (24*60*60)), // 1 day staked
            1, // multiplier
            2, // amountOfStakers
            accounts[0], // user address
            accounts[1], // collection address
            true
        );

        expect(await llth.balanceOf(accounts[0])).to.be.a.bignumber.equal(new BN(0)); // LLTH balance should be zero

        await harvest.harvest(accounts[1]); // (collection address)

        // need to wait for _fulfill() to be called by oracle
        await timeout(1000); 

        // reward = (numOfTokens*multiplier*daysStaked*rarity)/numberOfStakers = (3*1*1*100)/2 = 150
        expect(await llth.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(250)); // LLTH balance should = reward
    });
    */
    


    // truffle test test/2_polyharvest_test.js --compile-none

    // TO DO: use listen for event rather than timeouts to save time when running test
    
})