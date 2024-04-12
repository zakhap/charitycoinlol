//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";


// Useful for debugging. Remove when deploying to a live network.
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
}

contract LiquidityProvider is ReentrancyGuard, Ownable {
	IERC20Metadata public token;
	uint256 public charityFee; // Fee in percentage
	address public charityAddress;
	bool public isActive;
	uint256 public threshold;
	address public uniswapV3;
	address public weth;

	constructor(uint256 _charityFee, address _charityAddress, address _uniswapV3, address _weth) {
			charityFee = _charityFee;
			charityAddress = _charityAddress;
			isActive = false;
			uniswapv3 = _uniswapV3;
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
		uint256 fee = msg.value * charityFee / 100;
		uint256 amount = calculatePrice(supply, msg.value - fee, token.decimals(), 1 ether);
		// Transfer the tokens
		token.transfer(msg.sender, amount);
		payable(charityAddress).transfer(fee);
		// on threshold hook to create unipool (V2/V3???)
		if (supply < threshold) {
			// call hook
			// // 1. get weth
			uint256 contractBalance = address(this).balance;
			IWETH(weth).deposit{value: contractBalance}();
			// 2. create pool

			// 3. Fund pool
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
			payable(msg.sender).transfer(totalReturn);
    }
}


contract CharityCoinDeployer is ReentrancyGuard {
    // Hardcoded address to receive 10% of the total supply
    address public charityAddress;
		address public uniswapV3;
		address public weth; 

		event NewTokenCreated(address indexed tokenAddress, string name, string symbol, uint256 totalSupply);

    constructor(address _charityAddress, _uniswapV3, _weth) {
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
