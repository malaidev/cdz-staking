

const LLTH = artifacts.require("MockLLTH");


const Harvest = artifacts.require("Harvest");


const { duration, increaseTimeTo } = require('./utils');

var chai = require("./setupchai.js");
const BN = web3.utils.BN;
const expect = chai.expect;

const truffleAssert = require('truffle-assertions');
const { assert } = require('chai');



contract("Harvest - Polygon", async accounts => {
  

    beforeEach(async () => {

        llth = await LLTH.deployed();
        harvest = await Harvest.deployed()

    });


    
    it('Can harvest a single token', async () => {

        

    })

    


    // truffle test test/3_polyharvest_test.js --compile-none

    // use listen for event rather than timeouts to save time when running test
    
})