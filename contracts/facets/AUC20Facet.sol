pragma solidity ^0.8.23;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract AUC20Facet is ERC20 {
    constructor() ERC20("AUC Token", "AUC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
