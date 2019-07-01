/* global artifacts */
const colors = require('colors')

const Migrations = artifacts.require('./Migrations.sol')

module.exports = async (deployer, network) => {
  console.log(colors.magenta(`Network: ${network}`))
  await deployer.deploy(Migrations)
}
