pragma solidity ^0.5.0;

import "./Interfaces/IBadERC20.sol";
import "./Utils/Ownable.sol";
import "./Utils/SafeTransfer.sol";

contract BouncerProxy is Ownable {
  using SafeTransfer for address;

  // avoid replay attacks
  mapping(address => uint) public nonce;

  // allow for third party metatx account to make transactions through this
  // contract like an identity but make sure the owner has whitelisted the tx
  mapping(address => bool) public whitelist;

  // whitelist the deployer so they can whitelist others
  constructor() public {
    whitelist[msg.sender] = true;
  }

  event UpdateWhitelist(address _account, bool _value);
  event Received (address indexed sender, uint value);
  // when some frontends see that a tx is made from a bouncerproxy, they may want to parse through these events to find out who the signer was etc
  event Forwarded (
    bytes sig,
    address signer,
    address destination,
    uint value,
    bytes data,
    address rewardToken,
    uint rewardAmount,
    bytes32 _hash
  );

  // copied from https://github.com/uport-project/uport-identity/blob/develop/contracts/Proxy.sol
  function () external payable {
    emit Received(msg.sender, msg.value);
  }

  function updateWhitelist(
    address _account,
    bool _value
  )
    public
    onlyOwner
    returns (bool)
  {
    // This allow every whitelisted address to whitelist someone
    // require(whitelist[msg.sender],"BouncerProxy::updateWhitelist Account Not Whitelisted");
    whitelist[_account] = _value;
    emit UpdateWhitelist(_account, _value);
    return true;
  }

  function getHash(
    address signer,
    address destination,
    uint value,
    bytes memory data,
    address rewardToken,
    uint rewardAmount
  )
    public
    view
    returns (bytes32)
  {
    return keccak256(
      abi.encodePacked(
        address(this),
        signer,
        destination,
        value,
        data,
        rewardToken,
        rewardAmount,
        nonce[signer]
      )
    );
  }

  // original forward function copied from https://github.com/uport-project/uport-identity/blob/develop/contracts/Proxy.sol
  function forward(
    bytes memory sig,
    address signer,
    address destination,
    uint value,
    bytes memory data,
    address rewardToken,
    uint rewardAmount
  )
    public
    returns (bool)
  {
    //the hash contains all of the information about the meta transaction to be called
    bytes32 _hash = getHash(
      signer,
      destination,
      value,
      data,
      rewardToken,
      rewardAmount
    );
    //increment the nonce counter so this tx can't run again
    nonce[signer] += 1;
    //this makes sure signer signed correctly AND signer is a valid bouncer
    require(
      signerIsWhitelisted(_hash, sig),
      "fn: forward(), msg: forward Signer is not whitelisted"
    );
    // make sure the signer pays in whatever token (or ether) the sender and signer agreed to
    // or skip this if the sender is incentivized in other ways and there is no need for a token
    if (rewardAmount > 0) {
      // address 0 mean reward with ETH
      if (rewardToken == address(0)){
        // reward with ETH
        msg.sender.transfer(rewardAmount);
      } else {
        // reward token
        require(
          rewardToken._safeTransfer(
            msg.sender,
            rewardAmount
          ),
          "fn: forward(), msg: token transfer failed"
        );
      }
    }
    // execute the transaction with all the given parameters
    require(
      executeCall(destination, value, data),
      "fn: forward(), msg: executeCall() function failed"
    );
    emit Forwarded(
      sig,
      signer,
      destination,
      value,
      data,
      rewardToken,
      rewardAmount,
      _hash
    );

    return true;
  }

  // copied from https://github.com/uport-project/uport-identity/blob/develop/contracts/Proxy.sol
  // which was copied from GnosisSafe
  // https://github.com/gnosis/gnosis-safe-contracts/blob/master/contracts/GnosisSafe.sol
  function executeCall(
    address to,
    uint256 value,
    bytes memory data
  )
    internal
    returns (bool success)
  {
    // solium-disable-next-line security/no-inline-assembly
    assembly {
       success := call(gas, to, value, add(data, 0x20), mload(data), 0, 0)
    }
  }

  //borrowed from OpenZeppelin's ESDA stuff:
  //https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/cryptography/ECDSA.sol
  function signerIsWhitelisted(
    bytes32 _hash,
    bytes memory _signature
  )
    internal
    view
    returns (bool)
  {
    bytes32 r;
    bytes32 s;
    uint8 v;
    // Check the signature length
    if (_signature.length != 65) {
      return false;
    }
    // Divide the signature in r, s and v variables
    // ecrecover takes the signature parameters, and the only way to get them
    // currently is to use assembly.
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      r := mload(add(_signature, 32))
      s := mload(add(_signature, 64))
      v := byte(0, mload(add(_signature, 96)))
    }
    // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
    if (v < 27) {
      v += 27;
    }
    // If the version is correct return the signer address
    if (v != 27 && v != 28) {
      return false;
    } else {
      // solium-disable-next-line arg-overflow
      return whitelist[ecrecover(
        keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)),
        v, r, s
      )];
    }
  }
}