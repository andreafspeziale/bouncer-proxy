pragma solidity ^0.5.0;

import { ERC20Detailed } from "../../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import { ERC20 } from "../../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20Detailed, ERC20{

  mapping (address => uint256) private _balances;
  uint256 private _totalSupply;

  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    uint totalSupply_
  )
    public
    ERC20Detailed(_name, _symbol, _decimals)
  {
    _totalSupply = totalSupply_;
    _balances[msg.sender] = totalSupply_;
  }
}
