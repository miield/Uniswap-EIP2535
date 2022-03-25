import { ethers } from 'hardhat';

async function main() {

  const SwapiiFactory = await ethers.getContractFactory("contracts/SwapiiFactory.sol:SwapiiFactory");
  const swapiiFactory = await SwapiiFactory.deploy();

  await swapiiFactory.deployed();
  console.log("Swapii Factory deployed to:", swapiiFactory.address);

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
