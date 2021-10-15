const Masterdemon = artifacts.require("Masterdemon");
const MockLLTH = artifacts.require("MockLLTH");
const MockCollection = artifacts.require("MockCollection");

module.exports = async (deployer) => {
    await deployer.deploy(MockCollection);

    await deployer.deploy(MockLLTH)
        .then((pre) => deployer.deploy(Masterdemon, pre.address))
}