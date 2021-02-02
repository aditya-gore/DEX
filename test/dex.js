// Import mock ERC20 tokens.
const Dai = artifacts.require("mocks/Dai.sol");
const Bat = artifacts.require("mocks/Bat.sol");
const Rep = artifacts.require("mocks/Rep.sol");
const Zrx = artifacts.require("mocks/Zrx.sol");

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
  });
});
