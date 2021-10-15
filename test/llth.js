const MockLLTH = artifacts.require("MockLLTH");
const MockCollection = artifacts.require("MockCollection");

const MasterDemon = artifacts.require("Masterdemon");

contract("MockLLTH", async accounts => {

  console.log("--------- Accounts ----------");
  for(var i = 0; i < accounts.length; i++) {
    console.log(accounts[i]);
  }
  console.log("-----------------------------");

  it("[ MockLLTH ] should mint LLTH", async () => {
    const llth = await MockLLTH.deployed();
    const mintBalance = await llth.balanceOf.call(accounts[0]);
    assert.equal(mintBalance.valueOf(), 1000000000*(10**18));
  });

  it("[ MasterDemon ] should minting 1 nft to account[0]", async () => {
    const collection = await MockCollection.deployed();
    await collection.mint(1);
    const mintNFTBalance = await collection.balanceOf.call(accounts[0]);
    assert.equal(mintNFTBalance, 1);
  });
  
  it("[ MasterDemon ] staking nft 0 of account[0] to staking contract", async () => {
    const collection = await MockCollection.deployed();
    const masterDemon = await MasterDemon.deployed();

    // set NFT collection, collection id will be 0
    await masterDemon.setCollection(true, collection.address, 0, 0, 0, 1, 2, 0);

    // stake with Params cid: 0, nftId: 0
    await collection.approve(masterDemon.address, 0);
    await masterDemon.stake(0, 0);

    // get staked amount of nft in MasterDemon contract
    const amountNftStaked = await collection.balanceOf.call(masterDemon.address);
    assert.equal(amountNftStaked, 1, "NFT wasn't staked to MasterDemon Contract");
  });
  
  it("[ MasterDemon ] unstaking nft 0 of staking contract to account[0]", async () => {
    const collection = await MockCollection.deployed();
    const masterDemon = await MasterDemon.deployed();

    // unstake with Params cid: 0, nftId: 0
    // await collection.approve(masterDemon.address, 0);
    await masterDemon.unstake(0, 0);

    // get staked amount of nft in MasterDemon contract
    const amountNftStaked = await collection.balanceOf.call(masterDemon.address);
    assert.equal(amountNftStaked, 0, "NFT wasn't unstaked from MasterDemon contract");
  });

});