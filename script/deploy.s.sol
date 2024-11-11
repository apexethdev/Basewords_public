// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BaseWords} from "../src/BaseWords.sol";

/// forge script script/deploy.s.sol:Sepolia --rpc-url $BASE --broadcast --verify

contract Sepolia is Script {
    uint256 public mintPrice = 0.001 ether;
    string private rpcUrl;
    uint256 private deployerPrivateKey;

    function setUp() public {
        rpcUrl = vm.envString("BASE");
        console.log("Using RPC URL:", rpcUrl);
        deployerPrivateKey = vm.envUint("KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        BaseWords wordsContract = new BaseWords();
        console.log("BaseWords contract deployed at:", address(wordsContract));

        // wordsContract.toggleMinting();
        console.log("Minting toggled");
        vm.stopBroadcast();
    }
}
