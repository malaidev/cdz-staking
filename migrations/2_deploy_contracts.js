const Masterdemon = artifacts.require("Masterdemon");
const LLTH = artifacts.require("LLTH");
const Collection = artifacts.require("Collection");

module.exports = async (deployer) => {
    await deployer.deploy(Collection);

    await deployer.deploy(LLTH)
        .then((pre) => deployer.deploy(Masterdemon, pre.address))
}