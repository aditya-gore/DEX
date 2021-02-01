pragma solidity ^0.6.3;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract Bat is ERC20 {
    constructor() public ERC20("Brave browser token", "BAT") {}

    // To get some free tokens for testing our smart contract. This is called a faucet.
    function faucet(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
