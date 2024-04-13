import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Deploys a contract named "YourContract" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployYourContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network sepolia`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
    
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const weth = `0x4200000000000000000000000000000000000006`; // base + base sepolia
  // const uniswap = `0x33128a8fC17869897dcE68Ed026d694621f6FDfD`; // base
  const uniswap = `0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24`; // base sepolia

  const CharityCoinDeployer = await deploy("CharityCoinDeployer", {
    from: deployer,
    args: [deployer, uniswap, weth],
    log: true,
    autoMine: true,
  });
  console.log("CharitycoinFactory Address:", CharityCoinDeployer.address);
};

export default deployYourContract;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags YourContract
deployYourContract.tags = ["CharityCoin"];
