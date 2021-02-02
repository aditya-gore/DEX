// Import mock ERC20 tokens.
const Dai = artifacts.require("mocks/Dai.sol");
const Bat = artifacts.require("mocks/Bat.sol");
const Rep = artifacts.require("mocks/Rep.sol");
const Zrx = artifacts.require("mocks/Zrx.sol");

// Import contract abstraction of the Decentralized Exchange
const Dex = artifacts.require("Dex.sol");

// Create byte32 variables using web3 for ticker argument
const [DAI, BAT, REP, ZRX] = ["DAI", "BAT", "REP", "ZRX"].map((ticker) =>
  web3.utils.fromAscii(ticker)
);

// Define cotract block to write tests.
contract("Dex", () => {
  // Variables pointing to ERC20 tokens.
  let dai, bat, rep, zrx;
  // Deploy tokens in a before-each hook (Runs before each test).
  beforeEach(async () => {
    [dai, bat, rep, zrx] = await Promise.all([
      // Returns an array of four contract instances,
      // Stored one in each variable by 'Array Destructuring'.
      Dai.new(),
      Bat.new(),
      Rep.new(),
      Zrx.new(),
    ]);
    const dex = await Dex.new(); // Deploy Dex smart contract.
    // Configure ERC20 tokens in the Dex (Call addToken for each token)
    await Promise.all([
      dex.addToken(DAI, dai.address),
      dex.addToken(BAT, bat.address),
      dex.addToken(REP, rep.address),
      dex.addToken(ZRX, zrx.address),
    ]);
  });
});
