const Masterdemon = artifacts.require("Masterdemon");
const MockLLTH = artifacts.require("MockLLTH");
const MockCollection = artifacts.require("MockCollection");

module.exports = async (deployer) => {
    deployer.deploy(MockLLTH).then(res => {
        deployer.deploy(Masterdemon, res.address)
    })

    await deployer.deploy(MockCollection);
}