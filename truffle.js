module.exports = {
  solc: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  networks: {
    development: { // $ npm run ganache
      host: 'localhost',
      port: 7545,
      network_id: '47',
      gas: 4700000,
      gasPrice: 6000000000,
    },
    coverage: {
      host: 'localhost',
      network_id: '48',
      port: 7545,
      gas: 17592186044415,
      gasPrice: 1,
    },
  },
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions: {
      // gasPrice: config.gasPriceGWei, // if commented it's using the ethgasstation standard value
      currency: 'CHF',
    },
  },
}
