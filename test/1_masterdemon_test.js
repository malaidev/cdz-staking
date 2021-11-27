const Collection = artifacts.require('MockCollection');
const Masterdemon = artifacts.require('Masterdemon');
const { assert } = require('chai');
const truffleAssert = require('truffle-assertions');
const Web3 = require('web3');


contract(
    "Masterdemon - Main tests",
    async (accounts) => {
        let masterdemon;
        let collection;
        
        beforeEach(async () => {
            masterdemon = await Masterdemon.new();
            collection = await Collection.new();

            web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:9545"));

            collection.mint(10, accounts[0]);
            collection.mint(10, accounts[2]);
            masterdemon.setDev(accounts[1]);

            masterdemon.setCollection(
                true,
                collection.address,
                web3.utils.toWei("0.01", "ether"),
                0,
                10,
                50,
                7
            );
        });

        it("[Masterdemon, collection] Should deploy", async () => {
            assert(collection.address != '');
            assert(masterdemon.address != '');
        });

        it("[Masterdemon] General Staking Test", async () => {
            let balanceBefore;
            let balanceAfter;
            await collection.setApprovalForAll(masterdemon.address, true);
            await web3.eth.getBalance(masterdemon.address).then(res => balanceBefore = web3.utils.fromWei(res, "ether"));
            await masterdemon.stake(0, 0, { from: accounts[0], value: web3.utils.toWei("0.01", "ether") });
            await masterdemon.batchStake(0, [1, 2, 3], { from: accounts[0], value: web3.utils.toWei("0.03", "ether")});
            await web3.eth.getBalance(masterdemon.address).then(res => balanceAfter = web3.utils.fromWei(res, "ether"));
            assert.equal(Number((balanceAfter - balanceBefore).toFixed(2)), 0.04)

            let stakedAmount;
            await masterdemon.getUserInfo(accounts[0], collection.address).then(res => {
                stakedAmount = res['2'].words[0];
            })
            assert.equal(stakedAmount, 4);
        });

        it("[Masterdemon] General Unstaking Test", async () => {
            let amountOfStakers;
            await collection.setApprovalForAll(masterdemon.address, true, { from: accounts[0] });
            await masterdemon.batchStake(0, [1, 2, 3, 4, 5], { from: accounts[0], value: web3.utils.toWei("0.05", "ether")});
            await collection.setApprovalForAll(masterdemon.address, true, { from: accounts[2] });
            await masterdemon.batchStake(0, [10, 11, 12], { from: accounts[2], value: web3.utils.toWei("0.05", "ether")});

            await masterdemon.getCollectionInfo(0).then(res => {
                amountOfStakers = res['4'].words[0];
            })

            assert.equal(amountOfStakers, 2);

        })
    }
)