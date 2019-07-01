module.exports = {
  testrpcOptions: '-p 7545 -g 1 -i 48 -a 10',
  norpc: false,
  dir: '.',
  copyPackages: ['openzeppelin-solidity', 'truffle'],
  skipFiles: ['Migrations.sol', 'Utils/Ownable.sol', 'Utils/SafeTransfer.sol', 'Mocks/BadToken.sol','Interfaces/IBadERC20'],
  compileCommand: '../node_modules/.bin/truffle compile',
  testCommand: '../node_modules/.bin/truffle test --network coverage',
};