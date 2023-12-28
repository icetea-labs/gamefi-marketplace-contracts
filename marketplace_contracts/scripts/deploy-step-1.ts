import { ethers } from "hardhat";

// source: https://etherscan.io/address/wyverntoken.eth#code Constructor Arguments
const UTXOAMOUNT = 185976814178002
const UTXOMERKLEROOT = process.env.UTXOMERKLEROOT || "0x0000000"

async function main() {
  const MerkleProof = await ethers.getContractFactory("contracts/MerkleProof.sol:MerkleProof");
  const merkleProof = await MerkleProof.deploy();
  await merkleProof.deployed();

  const WyvernToken = await ethers.getContractFactory("WyvernToken");
  const wyvernToken = await WyvernToken.deploy(UTXOMERKLEROOT, UTXOAMOUNT);
  await wyvernToken.deployed();

  const WyvernDAO = await ethers.getContractFactory("WyvernDAO");
  const wyvernDAO = await WyvernDAO.deploy(wyvernToken.address);
  await wyvernDAO.deployed();

  const WyvernDAOProxy = await ethers.getContractFactory("WyvernDAOProxy");
  const wyvernDAOProxy = await WyvernDAOProxy.deploy();
  await wyvernDAOProxy.deployed();

  const WyvernAtomicizer = await ethers.getContractFactory("WyvernAtomicizer");
  const wyvernAtomicizer = await WyvernAtomicizer.deploy();
  await wyvernAtomicizer.deployed();

  const WyvernProxyRegistry = await ethers.getContractFactory("WyvernProxyRegistry");
  const wyvernProxyRegistry = await WyvernProxyRegistry.deploy();
  await wyvernProxyRegistry.deployed();

  const WyvernTokenTransferProxy = await ethers.getContractFactory("WyvernTokenTransferProxy");
  const wyvernTokenTransferProxy = await WyvernTokenTransferProxy.deploy(wyvernProxyRegistry.address);
  await wyvernTokenTransferProxy.deployed();

  const data = {
    MerkleProof: merkleProof.address,
    wyvernToken: wyvernToken.address,
    wyvernDAO: wyvernDAO.address,
    wyvernDAOProxy: wyvernDAOProxy.address,
    wyvernAtomicizer: wyvernAtomicizer.address,
    wyvernProxyRegistry: wyvernProxyRegistry.address,
    wyvernTokenTransferProxy: wyvernTokenTransferProxy.address,
  }

  console.log(data)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
})

