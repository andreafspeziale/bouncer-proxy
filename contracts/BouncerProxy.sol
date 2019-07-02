pragma solidity ^0.5.0;

import "./Interfaces/IBadERC20.sol";
import "./Utils/Ownable.sol";
import "./Utils/SafeTransfer.sol";

contract BouncerProxy is Ownable {
  using SafeTransfer for address;

  // avoid replay attacks
  mapping(address => uint) public nonce;

  // allow for third party metatx account to make transactions through this
  // contract like an identity but make sure the owner has whitelisted the account
  mapping(address => bool) public whitelist;

  // whitelist the deployer so they can whitelist others
  constructor() public {
    whitelist[msg.sender] = true;
  }

  event LogUpdateWhitelist(address indexed _account, bool _value);

  event LogTransactionForward(
    bytes _signedHashedMessage,
    address indexed _signer,
    address indexed _recipient,
    uint _transactionObjectValueField,
    bytes _transactionObjectDataField,
    address _rewardTokenAddress,
    uint _rewardAmount,
    bytes32 _hash
  );

  function () external payable { }

  function updateWhitelist(
    address _account,
    bool _value
  )
    public
    onlyOwner
    returns (bool)
  {
    whitelist[_account] = _value;
    emit LogUpdateWhitelist(_account, _value);
    return true;
  }

  function getHash(
    address _signer,
    address _recipient,
    uint _transactionObjectValueField,
    bytes memory _transactionObjectDataField,
    address _rewardTokenAddress,
    uint _rewardAmount
  )
    public
    view
    returns (bytes32)
  {
    return keccak256(
      abi.encodePacked(
        address(this),
        _signer,
        _recipient,
        _transactionObjectValueField,
        _transactionObjectDataField,
        _rewardTokenAddress,
        _rewardAmount,
        nonce[_signer]
      )
    );
  }

  // original forward function copied from https://github.com/uport-project/uport-identity/blob/develop/contracts/Proxy.sol
  function forward(
    bytes memory _signedHashedMessage,
    address _signer,
    address _recipient,
    uint _transactionObjectValueField,
    bytes memory _transactionObjectDataField,
    address _rewardTokenAddress,
    uint _rewardAmount
  )
    public
    returns (bool)
  {
    bytes32 hashedMessage = getHash(
      _signer,
      _recipient,
      _transactionObjectValueField,
      _transactionObjectDataField,
      _rewardTokenAddress,
      _rewardAmount
    );

    //increment the nonce counter so this tx can't run again
    nonce[_signer] += 1;

    //this makes sure signer signed correctly AND signer is a valid bouncer
    require(
      isSignerWhitelisted(hashedMessage, _signedHashedMessage),
      "fn: forward(), msg: forward Signer is not whitelisted"
    );
    // make sure the signer pays in whatever token (or ether) the sender and signer agreed to
    // or skip this if the sender is incentivized in other ways and there is no need for a token
    if (_rewardAmount > 0) {
      // address 0 mean reward with ETH
      if (_rewardTokenAddress == address(0)){
        // reward with ETH
        msg.sender.transfer(_rewardAmount);
      } else {
        // reward token
        require(
          _rewardTokenAddress._safeTransfer(
            msg.sender,
            _rewardAmount
          ),
          "fn: forward(), msg: token transfer failed"
        );
      }
    }
    // execute the transaction with all the given parameters
    require(
      executeCall(_recipient, _transactionObjectValueField, _transactionObjectDataField),
      "fn: forward(), msg: executeCall() function failed"
    );
    emit LogTransactionForward(
      _signedHashedMessage,
      _signer,
      _recipient,
      _transactionObjectValueField,
      _transactionObjectDataField,
      _rewardTokenAddress,
      _rewardAmount,
      hashedMessage
    );

    return true;
  }

  // copied from https://github.com/uport-project/uport-identity/blob/develop/contracts/Proxy.sol
  // which was copied from GnosisSafe
  // https://github.com/gnosis/gnosis-safe-contracts/blob/master/contracts/GnosisSafe.sol
  function executeCall(
    address _to,
    uint256 _value,
    bytes memory _data
  )
    internal
    returns (bool success)
  {
    // solium-disable-next-line security/no-inline-assembly
    assembly {
       success := call(gas, _to, _value, add(_data, 0x20), mload(_data), 0, 0)
    }
  }

  //borrowed from OpenZeppelin's ESDA stuff:
  //https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/cryptography/ECDSA.sol
  function isSignerWhitelisted(
    bytes32 _hashedMessage,
    bytes memory _signedHashedMessage
  )
    internal
    view
    returns (bool)
  {
    bytes32 r;
    bytes32 s;
    uint8 v;
    // Check the signature length
    if (_signedHashedMessage.length != 65) {
      return false;
    }
    // Divide the signature in r, s and v variables
    // ecrecover takes the signature parameters, and the only way to get them
    // currently is to use assembly.
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      r := mload(add(_signedHashedMessage, 32))
      s := mload(add(_signedHashedMessage, 64))
      v := byte(0, mload(add(_signedHashedMessage, 96)))
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
        keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hashedMessage)),
        v, r, s
      )];
    }
  }
}