const Masterdemon = artifacts.require("Masterdemon");
const MockLLTH = artifacts.require("MockLLTH");
const MockCollection = artifacts.require("MockCollection");
const ArrayLib = artifacts.require("Array");

const Harvester = artifacts.require("Harvester"); 



module.exports = async (deployer) => {
    
    await deployer.deploy(ArrayLib);
    await deployer.deploy(Masterdemon);
    await deployer.link(ArrayLib, [Masterdemon]);
    await deployer.deploy(MockLLTH).then(res => {
        deployer.deploy(Harvest, res.address);
    })
    await deployer.deploy(MockCollection);

}