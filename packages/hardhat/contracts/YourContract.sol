//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";



import "hardhat/console.sol";
 
contract CharityCoin is ERC20, ReentrancyGuard {
    constructor(
        uint256 totalSupply,
        string memory name,
        string memory symbol,
        address[] memory holders,
        uint8[] memory percentages
    ) ERC20(name, symbol) {
        require(holders.length == percentages.length, "Mismatched holders and percentages arrays");

        uint256 totalPercentages;
        for (uint256 i = 0; i < holders.length; i++) {
						totalPercentages += percentages[i];
            _mint(holders[i], totalSupply * percentages[i] / 100);
        }
				require(totalPercentages == 100, "Percentages do not add up to 100");

    }
}

interface IWETH {
	function deposit() external payable;
	function balanceOf(address account) external view returns (uint256);
}

interface IUniV3 {
	function createPool(
		address tokenA,
		address tokenB,
		uint24 fee
	) external returns (address pool);

	struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
	}

	    function mint(MintParams calldata params) external payable returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}

contract LiquidityProvider is ReentrancyGuard, Ownable {
	IERC20Metadata public token;
	uint256 public charityFee; // Fee in percentage
	address public charityAddress;
	bool public isActive;
	uint256 public threshold;
	address public uniswapV3;
	address public weth;

	event CharitableDonation(address indexed donor, uint256 value);
	event NewPool(address indexed poolAddress, address indexed tokenA, address indexed tokenB);

	constructor(uint256 _charityFee, address _charityAddress, address _uniswapV3, address _weth) {
			charityFee = _charityFee;
			charityAddress = _charityAddress;
			isActive = false;
			uniswapV3 = _uniswapV3;
			weth = _weth;
	}

	function registerToken(address _token) external onlyOwner {
		uint256 pooltotal = IERC20Metadata(_token).balanceOf(address(this));
		require(pooltotal > 0);
		threshold = pooltotal * 70 / 100;
		token = IERC20Metadata(_token);
		isActive = true;
		transferOwnership(address(0));
	}

	/**
	 * @dev This function calculates the price of a token based on the current supply, the amount to be purchased, 
	 * the number of decimals the token uses, and a scalar value. The calculation is done using a bonding curve formula.
	 * 
	 * @param supply The current total supply of the token.
	 * @param amount The amount of tokens to be purchased.
	 * @param decimals The number of decimals the token uses.
	 * @param scalar A scalar value used to adjust the price calculation.
	 * 
	 * @return The calculated price for the specified amount of tokens.
	 */
	function calculatePrice(uint256 supply, uint256 amount, uint256 decimals, uint256 scalar) public pure returns (uint256) {
		// Calculate the first part of the summation formula. If the supply is 0, sum1 is 0.
		uint256 sum1 = supply == 0 ? 0 : (supply - 1) * supply * (2 * (supply - 1) + 1) / 6;
		
		// Calculate the second part of the summation formula
		uint256 sum2 = (supply == 0 && amount == 1) ? 0 : (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6;
		
		// Calculate the difference between sum2 and sum1.
		uint256 summation = sum2 - sum1;
		return summation * (10 ** decimals) / scalar;
	}

	function buy() external payable nonReentrant {
		require(isActive == true);
		uint256 supply = token.balanceOf(address(this));
		uint256 charityAmount = msg.value * charityFee / 100;
		uint256 amount = calculatePrice(supply, msg.value - charityAmount, token.decimals(), 1 ether);
		// Transfer the tokens
		token.transfer(msg.sender, amount);
		payable(charityAddress).transfer(charityAmount);
		emit CharitableDonation(msg.sender, charityAmount);

		// on threshold hook to create unipool (V2/V3???)
		if (supply < threshold) {
			// call hook
			// // 1. get weth
			uint256 contractBalance = address(this).balance;
			IWETH(weth).deposit{value: contractBalance}();
			// 2. create pool
			// Create a pair for WETH and the token
			address pool = IUniswapV3Factory(address(uniswapV3)).createPool(address(token), weth, 10000); // 1%
			emit NewPool(pool, address(token), weth);
				// 3. Fund pool
			uint256 wethAmount = IERC20(weth).balanceOf(address(this));
			uint256 tokenAmount = token.balanceOf(address(this));

			// Approve the Uniswap router to spend WETH and the token
			IERC20(weth).approve(address(uniswapV3), wethAmount);
			token.approve(address(uniswapV3), tokenAmount);

			// Define the parameters for mintPosition
			IUniV3.MintParams memory params = 
				IUniV3.MintParams(
					address(token),
					address(weth),
					10000,
					-887200,
					88720,
					tokenAmount,
					wethAmount,
					0,
					0,
					charityAddress,
					block.timestamp + 15 minutes
				);

			// // Mint a new position in the pool
			IUniV3(uniswapV3).mint{value: wethAmount}(params);

		}
	}

    function sell(uint256 amount) external nonReentrant {
			require(isActive == true);
			uint256 supply = token.balanceOf(address(this));
			uint256 price = calculatePrice(supply - amount, amount, token.decimals(), 1 ether);
			uint256 charityAmount = price * charityFee / 100;
			uint256 totalReturn = price - charityAmount;

			// Transfer the tokens
			token.transferFrom(msg.sender, address(this), amount);

			// Send the Ether
			payable(charityAddress).transfer(charityAmount);
			emit CharitableDonation(msg.sender, charityAmount);

			payable(msg.sender).transfer(totalReturn);
    }
}


contract CharityCoinDeployer is ReentrancyGuard {
    // Hardcoded address to receive 10% of the total supply
    address public charityAddress;
		address public uniswapV3;
		address public weth; 

		event NewTokenCreated(address indexed tokenAddress, string name, string symbol, uint256 totalSupply);

    constructor(address _charityAddress, address _uniswapV3,address  _weth) {
			charityAddress = _charityAddress;
			uniswapV3 = _uniswapV3;
			weth = _weth;
    }

		function createCharityToken(
        uint256 totalSupply,
        string memory name,
        string memory symbol
		) external nonReentrant {

			LiquidityProvider lpBaby = new LiquidityProvider(
				3,
				charityAddress,
				uniswapV3,
				weth
			);

			uint8[] memory percentages = new uint8[](2);
			percentages[0] = 95;
    	percentages[1] = 5;

			address[] memory holders = new address[](2);
			holders[0] = address(lpBaby);
			holders[1] = charityAddress;
			
			CharityCoin token = new CharityCoin(
				totalSupply,
				name,
				symbol,
				holders,
				percentages // 95% of the funds to the bonding curve, nonprofit gets to baghold for free
			);

			emit NewTokenCreated(address(token), name, symbol, totalSupply);

		}
}
