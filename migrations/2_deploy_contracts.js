const Masterdemon = artifacts.require("Masterdemon");
const MockLLTH = artifacts.require("MockLLTH");
const MockCollection = artifacts.require("MockCollection");

module.exports = async (deployer) => {
    await deployer.deploy(MockCollection);
    const llth = await deployer.deploy(MockLLTH);
    await deployer.deploy(Masterdemon, llth.address);
}