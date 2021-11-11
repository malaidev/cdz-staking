const Masterdemon = artifacts.require("Masterdemon");
const MockLLTH = artifacts.require("MockLLTH");
const MockCollection = artifacts.require("MockCollection");
const provableAPI = artifacts.require("usingProvable");
const ArrayLib = artifacts.require("Array");

module.exports = async (deployer) => {
    await deployer.deploy(provableAPI);
    await deployer.deploy(ArrayLib);
    await deployer.link(ArrayLib, [Masterdemon]);
    await deployer.deploy(MockLLTH).then(res => {
        deployer.deploy(Masterdemon, res.address)
    })
    await deployer.deploy(MockCollection);
}