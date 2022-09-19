// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
pragma abicoder v2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract LazyMinting is ERC721URIStorage, EIP712, AccessControl{

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string private constant SIGNING_NAME = "LazyMinting-Voucher";
    string private constant SIGNING_VERSION = "1.0";

    mapping(address => uint256) pendingWithdrawls;

    constructor(address payable minter) ERC721("LazyMintNFT", "LMN") EIP712(SIGNING_NAME, SIGNING_VERSION){
        _setupRole(MINTER_ROLE, minter);
    }

    struct NFTVoucher{
        uint256 tokenId;
        string uri;
        uint256 minPrice;
        bytes signature;
    }

    function redeem(address redeemer, NFTVoucher calldata voucher) public payable returns(uint256){
        // check the validity of the signature first and get the address of the signer
        //require(_verify(redeemer, voucher), "Verification Failed!");

        address signer = _verify(voucher);
        //console.log("Address of signer after verification : ", signer);

        // check that the signer has minter role or not
        require(hasRole(MINTER_ROLE, signer), "Signature is invalid or The redeemer is not authorized to mint the NFT");

        // check if the redeemer is paying enough to cover the buyer's cost
        require(msg.value >= voucher.minPrice, "Insufficient funds supplied to redeem NFT");

        // first assign the NFT to the signer's account
        _mint(signer, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);

        // now transfer it to the redeemer's account
        _transfer(signer, redeemer, voucher.tokenId);

        pendingWithdrawls[signer] += msg.value;

        return(voucher.tokenId);
    }

    function _verify(NFTVoucher calldata voucher) internal view returns(address){
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    function _hash(NFTVoucher calldata voucher) internal view returns(bytes32){
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(uint256 tokenId,string uri,uint256 minPrice)"), 
            voucher.tokenId, 
            keccak256(bytes(voucher.uri)),
            voucher.minPrice
        )));
    }

    function getChainId() external view returns(uint256){
        uint256 id;
        assembly{
            id := chainid()
        }
        return id;
    }

    function withdraw() public{
        require(hasRole(MINTER_ROLE, msg.sender), "Only authorized minters can withdraw!");
        require(availableToWithdraw() > 0, "Does not have enough funds!");
        address payable receiver = payable(msg.sender);
        uint amount = availableToWithdraw();
        console.log("Transferring amount :", pendingWithdrawls[receiver], "ETH to Account : ", receiver);
        pendingWithdrawls[receiver] = 0;
        receiver.transfer(amount);
    }

    function availableToWithdraw() public view returns(uint256){
        return pendingWithdrawls[msg.sender];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (AccessControl, ERC721) returns (bool) {
    return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
  }
}
