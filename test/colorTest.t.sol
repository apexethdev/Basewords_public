// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BaseWords.sol";
import "../src/WordData.sol";

// forge test --match-path test/colorTest.t.sol -vvv

contract ColorTest is Test {
    BaseWords baseWords;

    address deployer = address(77);
    address addr1 = address(0x714727Fa26f632AfFF8cff56258278FB72F896A0);

    uint256 mintPrice = 0.001 ether;

    function setUp() public {
        string memory rpcUrl = vm.envString("BSEP");
        uint256 forkId = vm.createFork(rpcUrl);
        vm.selectFork(forkId);

        uint256 currentBlockNumber = block.number;
        console.log("Current Block Number:", currentBlockNumber);

        vm.deal(deployer, 1 ether);
        vm.deal(addr1, 1 ether);

        vm.startPrank(deployer);
        baseWords = new BaseWords();
        baseWords.toggleMinting();
        vm.stopPrank();
    }

    // // /// i own color token id 2525 and 2526, i want to color my word
    function testColorMyWord() public {
        string[] memory words = new string[](1);
        words[0] = "WORD1";
        vm.startPrank(addr1);
        baseWords.mint{value: mintPrice}(words);

        BaseWords.TokenData memory data = baseWords.getTokenData(1);
        console.log("Background Color:", data.backgroundColor);
        console.log("Text Color:", data.textColor);
        console.log("Is Text Colored:", data.isTextColored);
        console.log("Is Background Colored:", data.isBackgroundColored);

        baseWords.updateBackgroundColor(1, 2525);
        baseWords.updateWordColor(1, 2526);

        /// add a console line break
        console.log("");

        /// check if the word is colored
        BaseWords.TokenData memory data2 = baseWords.getTokenData(1);
        console.log("Background Color:", data2.backgroundColor);
        console.log("Text Color:", data2.textColor);
        console.log("Is Text Colored:", data2.isTextColored);
        console.log("Is Background Colored:", data2.isBackgroundColored);

        /// reset the colors
        baseWords.resetColors(1);

        /// add a console line break
        console.log("");

        /// check if the word is colored
        BaseWords.TokenData memory data3 = baseWords.getTokenData(1);
        console.log("Background Color:", data3.backgroundColor);
        console.log("Text Color:", data3.textColor);
        console.log("Is Text Colored:", data3.isTextColored);
        console.log("Is Background Colored:", data3.isBackgroundColored);

        vm.stopPrank();
    }

    // Test resetting colors without deployership reverts
    function testResetColorsWithoutdeployershipReverts() public {
        string[] memory words = new string[](1);
        words[0] = "WORD1";
        vm.startPrank(addr1);
        baseWords.mint{value: mintPrice}(words);
        baseWords.updateBackgroundColor(1, 2525);
        baseWords.updateWordColor(1, 2526);
        vm.stopPrank();

        vm.startPrank(deployer);
        vm.expectRevert("Caller is not the owner");
        baseWords.resetColors(1);
        vm.stopPrank();
    }

    // Test inverting colors
    function testInvertColors() public {
        string[] memory words = new string[](1);
        words[0] = "WORD1";
        vm.startPrank(addr1);
        baseWords.mint{value: mintPrice}(words);
        baseWords.invertDefaultColors(1);
        vm.stopPrank();
    }

    // test calling all color functions
    function testAllColorFunctions() public {
        string[] memory words = new string[](1);
        words[0] = "WORD7";
        vm.startPrank(addr1);
        baseWords.mint{value: mintPrice}(words);
        baseWords.updateAllColors(1, 2525, 2526);
        string memory json = baseWords.buildAttributesJSON(1);
        console.log("JSON:", json); 
    }
}
