// truffle console --network mumbai
// truffle test test/2_polyharvest_test.js --compile-none

// TO DO: use listen for event rather than timeouts to save time when running test


    

const LLTH = artifacts.require("MockLLTH");
const Harvester = artifacts.require("Harvester");  
const LinkTokenInterface = artifacts.require('LinkTokenInterface');

var chai = require("./setupchai.js");
const BN = web3.utils.BN;
const expect = chai.expect;

const truffleAssert = require('truffle-assertions');
const { assert } = require('chai');




contract("Harvest - Polygon", async accounts => {

    let llth;
    let harvester;
  
    beforeEach(async () => {

        llth = await LLTH.deployed();
        console.log('llth token address:', llth.address)
        harvester = await Harvester.deployed()

    });


    
    it('Can harvest tokens', async () => {

        // funds Harvester contract with Link tokens to pay for oracle fees
        const token = await LinkTokenInterface.at("0x326C977E6efc84E512bB9C30f76E30c160eD06FB") // Link token address on Polygon Mumbai test net
        console.log('Funding contract:', harvester.address)
        await token.transfer(harvester.address, '30000000000000000') // 0.03 LINK
        console.log("Contract funded")
        console.log(parseInt((await harvester.viewLinkBalance()).toString())/(1e18)) 

        var epochStaked = (Math.round(Date.now() / 1000)) - (24*60*60)

        await harvester.setData(
            [1, 3, 5], // list of tokenId's
            epochStaked, // 1 day staked
            1, // multiplier
            1, // amountOfStakers
            accounts[0], // user address
            accounts[1], // collection address
            true // is stakable?
        );

        expect(await llth.balanceOf(accounts[0])).to.be.a.bignumber.equal(new BN(0)); // LLTH balance should be zero

        await harvester.harvest(accounts[1]); // (collection address)

        // need to wait for _fulfill() to be called by oracle
        function timeout(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }
        await timeout(30000); 

        // reward = (multiplier*daysStaked*rarity)/numberOfStakers = (1*1*100)/1 = 100
        expect(await llth.balanceOf(accounts[1])).to.be.a.bignumber.equal(new BN(300)); // LLTH balance should = reward
    });

    
})