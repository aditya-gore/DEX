pragma solidity ^0.6.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract Dai is ERC20 {
    constructor() public ERC20("Dai Stablecoin", "DAI") {}

    // To get some free tokens for testing our smart contract. This is called a faucet.
    function faucet(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
