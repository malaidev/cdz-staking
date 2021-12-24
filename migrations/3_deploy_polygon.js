const Harvest = artifacts.require('Harvest');
const MockXLLTH = artifacts.require('FxERC20');

module.exports = async (deployer) => {
  let llth;
  await deployer.deploy(MockXLLTH).then((res) => {
    llth = res.address;
  });
  await deployer.deploy(Harvest, llth);
};
