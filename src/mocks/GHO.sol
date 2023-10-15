pragma solidity ^0.8.13;

import "@openzeppelin/token/ERC20/ERC20.sol";

contract GHO is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {

    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}