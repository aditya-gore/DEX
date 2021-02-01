pragma solidity 0.6.3;
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";

contract Dex {
    using SafeMath for uint256; // To avoid the integer overflow bug.

    // Create an enum for the two types of orders
    enum Side {BUY, SELL}

    // Create a struct to represent each limit order.
    struct Order {
        uint256 id;
        address trader;
        Side side;
        bytes32 ticker;
        uint256 amount; // No of tokens.
        uint256 filled; // No of tokens fulfilled yet, initially zero.
        uint256 price;
        uint256 date;
    }

    // Struct to represent a token.
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }

    //A collection of tokens represented by a mapping which is indexed by the ticker of the token.
    mapping(bytes32 => Token) public tokens;

    // In order to iterate through all the tokens we need a list of all tickers.
    bytes32[] public tokenList;

    address public admin;

    // Constant to represent DAI token, computed at compile time instead of runtime, saves GAS.
    bytes32 constant DAI = bytes32("DAI");

    // To keep track of all tokens sent and the addresses who sent them.
    mapping(address => mapping(bytes32 => uint256)) public traderBalances;

    // Order Book - collection of all orders, Enum can be casted into integers.
    mapping(bytes32 => mapping(uint256 => Order[])) public orderBook;

    // Variable to keep track of current order id.
    uint256 public nextOrderId;

    // Variable to increment tradeId.
    uint256 public nextTradeId;

    // The order matching process will create a NewTrade event.
    event NewTrade(
        uint256 tradeId,
        uint256 orderId,
        bytes32 indexed ticker, // events can be filtered from front-end based on indexed variables.
        address indexed trader1,
        address indexed trader2,
        uint256 amount,
        uint256 price,
        uint256 date
    );

    constructor() public {
        admin = msg.sender;
    }

    // ----------------------------FUNCTIONS----------------------------------

    // To get the list of orders of the orderbook.
    function getOrders(bytes32 ticker, Side side)
        external
        view
        returns (Order[] memory)
    {
        return orderBook[ticker][uint256(side)];
    }

    // To get the list of tokens that can be traded.
    function getTokens() external view returns (Token[] memory) {
        Token[] memory _tokens = new Token[](tokenList.length);
        for (uint256 i = 0; i < tokenList.length; i++) {
            _tokens[i] = Token(
                tokens[tokenList[i]].ticker,
                tokens[tokenList[i]].tokenAddress
            );
        }
        return _tokens;
    }

    // Function to add a token in token registery.
    function addToken(bytes32 _ticker, address _tokenAddress)
        external
        onlyAdmin()
    {
        tokens[_ticker] = Token(_ticker, _tokenAddress);
        tokenList.push(_ticker);
    }

    // Deposit tokens to wallet.
    function deposit(uint256 amount, bytes32 ticker)
        external
        tokenExist(ticker)
    {
        IERC20(tokens[ticker].tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker]
            .add(amount);
    }

    // To withdraw tokens from wallet.
    function withdraw(uint256 amount, bytes32 ticker)
        external
        tokenExist(ticker)
    {
        require(
            traderBalances[msg.sender][ticker] >= amount,
            "Balance too low!"
        );
        traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker]
            .sub(amount);
        IERC20(tokens[ticker].tokenAddress).transfer(msg.sender, amount);
    }

    // Function to create a limit order.
    function createLimitOrder(
        bytes32 ticker,
        uint256 amount,
        uint256 price,
        Side side
    ) external tokenExist(ticker) toskenIsNotDai(ticker) {
        if (side == Side.SELL) {
            require(
                traderBalances[msg.sender][ticker] >= amount,
                "token balance too low"
            );
        } else {
            require(
                traderBalances[msg.sender][DAI] >= amount.mul(price),
                "dai balance too low"
            );
        }
        // Get a pointer to all the orders.
        Order[] storage orders = orderBook[ticker][uint256(side)];

        // Push the new order at the end of the orders array.
        orders.push(
            Order(nextOrderId, msg.sender, side, ticker, amount, 0, price, now)
        );

        // Bubble Sort. Best prices should appear at the beginning.

        // uint i = orders.length - 1; Bug! causes integer underflow when orders.length = 0.
        uint256 i = orders.length > 0 ? orders.length - 1 : 0;
        while (i > 0) {
            if (side == Side.BUY && orders[i - 1].price > orders[i].price) {
                break;
            }
            if (side == Side.SELL && orders[i - 1].price < orders[i].price) {
                break;
            }
            Order memory order = orders[i - 1];
            orders[i - 1] = orders[i];
            orders[i] = order;
            i--;
        }
        nextOrderId++;
    }

    // Function to create market orders
    function createMarketOrder(
        bytes32 ticker,
        uint256 amount,
        Side side
    ) external tokenExist(ticker) toskenIsNotDai(ticker) {
        if (side == Side.SELL) {
            require(
                traderBalances[msg.sender][ticker] >= amount,
                "Token balance too low"
            );
        }
        Order[] storage orders =
            orderBook[ticker][uint256(side == Side.BUY ? Side.SELL : Side.BUY)];
        uint256 i;
        uint256 remaining = amount;

        // Order matching process.
        while (i < orders.length && remaining > 0) {
            uint256 available = orders[i].amount.sub(orders[i].filled);
            uint256 matched = (remaining > available) ? available : remaining;
            remaining = remaining.sub(matched);
            orders[i].filled = orders[i].filled.add(matched);

            emit NewTrade(
                nextTradeId,
                orders[i].id,
                ticker,
                orders[i].trader,
                msg.sender,
                matched,
                orders[i].price,
                now
            );

            // Updating buyer and seller balances.
            if (side == Side.SELL) {
                traderBalances[msg.sender][ticker] = traderBalances[msg.sender][
                    ticker
                ]
                    .sub(matched);
                traderBalances[msg.sender][DAI] = traderBalances[msg.sender][
                    DAI
                ]
                    .add(matched.mul(orders[i].price));
                traderBalances[orders[i].trader][ticker] = traderBalances[
                    orders[i].trader
                ][ticker]
                    .add(matched);
                traderBalances[orders[i].trader][DAI] = traderBalances[
                    orders[i].trader
                ][DAI]
                    .sub(matched.mul(orders[i].price));
            }
            if (side == Side.BUY) {
                require(
                    traderBalances[msg.sender][DAI] >=
                        matched.mul(orders[i].price),
                    "dai balance too low"
                );
                traderBalances[msg.sender][ticker] = traderBalances[msg.sender][
                    ticker
                ]
                    .add(matched);
                traderBalances[msg.sender][DAI] = traderBalances[msg.sender][
                    DAI
                ]
                    .sub(matched.mul(orders[i].price));
                traderBalances[orders[i].trader][ticker] = traderBalances[
                    orders[i].trader
                ][ticker]
                    .sub(matched);
                traderBalances[orders[i].trader][DAI] = traderBalances[
                    orders[i].trader
                ][DAI]
                    .add(matched.mul(orders[i].price));
            }
            nextTradeId = nextTradeId.add(1);
            i = i.add(1);
        }

        // Prune the orderbook; Removing orders that were completely matched.
        i = 0;
        while (i < orders.length && orders[i].filled == orders[i].amount) {
            for (uint256 j = i; j < orders.length - 1; j++) {
                orders[j] = orders[j + 1];
            }
            orders.pop();
            i = i.add(1);
        }
    }

    //------------------MODIFIERS------------------

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admins is allowed!");
        _;
    }

    // Modifier to check if token exists
    modifier tokenExist(bytes32 ticker) {
        require(
            tokens[ticker].tokenAddress != address(0),
            "Token does not exist!"
        );
        _;
    }

    // Modifier to check if token is not DAI. Quote currency cannot be traded.
    modifier toskenIsNotDai(bytes32 ticker) {
        require(ticker != "DAI", "Can not trade DAI");
        _;
    }
}
