const Harvest = artifacts.require('Harvest');
const MockLLTH = artifacts.require('MockLLTH');

module.exports = async (deployer) => {
  let llth;
  await deployer.deploy(MockLLTH).then((res) => {
    llth = res.address;
  });
  await deployer.deploy(Harvest, llth);
};
