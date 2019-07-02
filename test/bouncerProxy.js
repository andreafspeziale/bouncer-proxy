/* eslint-env node, mocha */
/* global artifacts, contract, expect, web3 */
/* eslint no-underscore-dangle: 1 */
const BigNumber = web3.utils.BN

const BouncerProxy = artifacts.require('./BouncerProxy.sol')
const Counter = artifacts.require('./Mocks/MockCounter.sol')
const ERC20 = artifacts.require('./Mocks/MockToken.sol')

contract('BouncerProxy', (accounts) => {
  const [BouncerProxyOwner] = accounts
  // no ETH
  const [, sender] = accounts
  // will pay the blockchain fees in behalf of the sender
  const [, , miner] = accounts
  // whoever
  const [, , , whoever] = accounts

  const tokenName = 'MockToken'
  const tokenSymbol = 'ERC20'
  const initialTotalSupply = web3.utils.toWei('10000000000000000000')
  const decimals = 18

  describe('Delegated calls', () => {
    let BouncerProxyInstance
    let MockTokenInstance
    let MockCounterContract

    beforeEach(async () => {
      // deploy BouncerProxy
      BouncerProxyInstance = await BouncerProxy.new({ from: BouncerProxyOwner })

      // allow signer
      await BouncerProxyInstance.updateWhitelist(sender, true, { from: BouncerProxyOwner })
    })

    describe('Proxing with a reward', async () => {
      beforeEach(async () => {
        // deploy mock token
        MockTokenInstance = await ERC20.new(
          tokenName,
          tokenSymbol,
          decimals,
          initialTotalSupply,
          { from: sender },
        )
        await MockTokenInstance.mint(BouncerProxyInstance.address, web3.utils.toWei('10'), { from: sender })
      })
      describe('Simple contract interation', async () => {
        beforeEach(async () => {
          // deploy mock counter contract
          MockCounterContract = await Counter.new({ from: whoever })
        })
        it('Should be possible to increment the counter of the Counter contract without paying any fee by the sender', async () => {
          const REWARD = new BigNumber(web3.utils.toWei('10'))

          const initialSenderETHBalance = await web3.eth.getBalance(sender)
          const initialCounter = await MockCounterContract.counter.call({ from: whoever })

          // create the sender transaction to be sent by the proxy

          // SENDER TX GAS PRICE FIELD
          const senderWantedGasPriceUsage = new BigNumber('1')

          // SENDER TX DATA FIELD
          const countDataTransactionField = MockCounterContract
            .contract
            .methods
            .count().encodeABI()

          // SENDER TX VALUE FIELD
          const senderTransactionValue = new BigNumber('0')

          // SENDER TX NONCE FIELD (TAKEN FROM PROXY NONCE COUNTER)
          const senderBouncerNonce = new BigNumber(await BouncerProxyInstance.nonce.call(sender))

          const messageToBeHashed = [
            BouncerProxyInstance.address,
            sender,
            MockCounterContract.address,
            web3.utils.toTwosComplement(senderTransactionValue),
            countDataTransactionField,
            MockTokenInstance.address,
            web3.utils.toTwosComplement(REWARD),
            web3.utils.toTwosComplement(senderBouncerNonce),
          ]

          const messageHashed = web3.utils.soliditySha3(...messageToBeHashed)

          const messageHashedByPorxyContract = await BouncerProxyInstance.getHash.call(
            messageToBeHashed[1],
            messageToBeHashed[2],
            messageToBeHashed[3],
            messageToBeHashed[4],
            messageToBeHashed[5],
            messageToBeHashed[6],
          )

          expect(messageHashed).to.equal(messageHashedByPorxyContract)

          const messageSigned = await web3.eth.sign(messageHashed, sender)

          const forwardGasEstimation = new BigNumber(
            await BouncerProxyInstance.forward.estimateGas(
              messageSigned,
              sender,
              MockCounterContract.address,
              senderTransactionValue.toString(),
              countDataTransactionField,
              MockTokenInstance.address,
              REWARD.toString(),
            ),
          )

          await BouncerProxyInstance.forward(
            messageSigned,
            sender,
            MockCounterContract.address,
            senderTransactionValue,
            countDataTransactionField,
            MockTokenInstance.address,
            REWARD,
            { from: miner, gas: forwardGasEstimation, gasPrice: senderWantedGasPriceUsage },
          )

          const finalSenderETHBalance = await web3.eth.getBalance(sender)

          expect(finalSenderETHBalance).to.equal(initialSenderETHBalance)

          const finalCounter = await MockCounterContract.counter.call({ from: whoever })

          expect(finalCounter.toString()).to.equal(initialCounter.add(new BigNumber('1')).toString())

          const finalMinerTokenBalance = await MockTokenInstance.balanceOf.call(miner, { from: whoever })

          expect(finalMinerTokenBalance.toString()).to.equal(REWARD.toString())
        })
      })
    })
  })
})
