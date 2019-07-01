pragma solidity ^0.5.0;

contract MockCounter {

  uint public counter;

  constructor() public { }

  function () external payable {
    revert("fn: fallback, msg: fallback function not allowed");
  }

  function count() public returns (bool) {
    counter += 1;
    return true;
  }
}
