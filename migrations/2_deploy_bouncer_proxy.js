/* global artifacts */
const BouncerProxy = artifacts.require('./BouncerProxy.sol')

module.exports = async (deployer) => {
  await deployer.deploy(BouncerProxy)
}
