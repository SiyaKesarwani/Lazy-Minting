const hardhat = require("hardhat");
const { ethers } = hardhat;
const { LazyMintLibrary } = require('../lib')

async function deploy(){
const [minter, redeemer] = await ethers.getSigners()

const factory = await ethers.getContractFactory("LazyMinting")
const contract = await factory.deploy(minter.address)
await contract.deployed();
/*console.log("Address of Minter : ", minter.address)
console.log("Address of Redeemer : ", redeemer.address)
console.log("Contract is deployed at : ", contract.address)
*/


// the redeemerContract is an instance of the contract that's wired up to the redeemer's signing key
const redeemerFactory = factory.connect(redeemer)
const redeemerContract = redeemerFactory.attach(contract.address)
//console.log("Redeemer Contract is deployed at :", redeemerContract.address)

const lazyMinter = new LazyMintLibrary({ contract, signer: minter });
const voucher = await lazyMinter.createVoucher(1, "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi", 2);
//console.log("Signature passed : ",voucher.signature)
await redeemerContract.redeem(redeemer.address, voucher, {value: 2})

console.log("Successfully Minted an NFT to Address :", redeemer.address)

await contract.withdraw()

console.log("Successfully withdrawn earned amount to the Signer : ", minter.address)
}

deploy();
