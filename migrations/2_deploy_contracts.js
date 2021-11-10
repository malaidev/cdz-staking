const Masterdemon = artifacts.require("Masterdemon");
const MockLLTH = artifacts.require("MockLLTH");
const MockCollection = artifacts.require("MockCollection");
const provableAPI = artifacts.require("usingProvable");

module.exports = async (deployer) => {
    await deployer.deploy(provableAPI);
    await deployer.deploy(MockLLTH).then(res => {
        deployer.deploy(Masterdemon, res.address)
    })

    await deployer.deploy(MockCollection);
}