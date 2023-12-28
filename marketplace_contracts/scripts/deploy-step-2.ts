import { ethers } from "hardhat";

async function main () {
  const wyvernProxyRegistry = (await ethers.getContractFactory('WyvernProxyRegistry')).attach(process.env.WYVERN_PROXY_REGISTRY_ADDRESS)
  const wyvernTokenTransferProxy = (await ethers.getContractFactory('WyvernTokenTransferProxy')).attach(process.env.WYVERN_TOKEN_TRANSFER_PROXY_ADDRESS)
  const wyvernToken = (await ethers.getContractFactory('WyvernToken')).attach(process.env.WYVERN_TOKEN_ADDRESS)
  const wyvernDAOProxy = (await ethers.getContractFactory('WyvernDAOProxy')).attach(process.env.WYVERN_DAO_PROXY_ADDRESS)

  const WyvernExchange = await ethers.getContractFactory("WyvernExchange");
  const wyvernExchange = await WyvernExchange.deploy(
    wyvernProxyRegistry.address,
    wyvernTokenTransferProxy.address,
    wyvernToken.address,
    wyvernDAOProxy.address
  );

  await wyvernExchange.deployed();

  console.log('Exchange contract:', wyvernExchange.address)
  await wyvernProxyRegistry.grantInitialAuthentication(wyvernExchange.address)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
})
