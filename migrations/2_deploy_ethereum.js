const Masterdemon = artifacts.require('Masterdemon');
const MockCollection = artifacts.require('MockCollection');
const ArrayLib = artifacts.require('Array');

module.exports = async (deployer) => {
  await deployer.deploy(ArrayLib);
  await deployer.link(ArrayLib, [Masterdemon]);
  await deployer.deploy(Masterdemon);
  await deployer.deploy(MockCollection);
};
