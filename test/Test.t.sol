// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BaseWords.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BaseWordsTest is Test {
    using Strings for uint256;

    BaseWords baseWords;

    address owner = address(77);
    address addr1 = address(1);

    uint256 mintPrice = 0.001 ether;

    function setUp() public {
        string memory rpcUrl = vm.envString("BSEP");
        uint256 forkId = vm.createFork(rpcUrl);
        vm.selectFork(forkId);

        console.log("RPC URL:", rpcUrl);

        uint256 currentBlockNumber = block.number;
        console.log("Current Block Number:", currentBlockNumber);

        vm.deal(owner, 1 ether);
        vm.deal(addr1, 1 ether);

        vm.startPrank(owner);
        baseWords = new BaseWords();
        baseWords.toggleMinting();
        vm.stopPrank();
    }

    function testToggleMinting() public {
        vm.prank(owner);
        baseWords.toggleMinting();
        assertEq(baseWords.mintEnabled(), false);

        vm.prank(owner);
        baseWords.toggleMinting();
        assertEq(baseWords.mintEnabled(), true);
    }

    function testWithdraw() public {
        uint256 initialBalance = owner.balance;

        vm.prank(owner);
        baseWords.withdraw();

        assertEq(owner.balance, initialBalance + address(baseWords).balance);
    }

    /// write a test to check only owner can block nft
    function testOnlyOwnerCanBlockNft() public {
        vm.prank(addr1);
        vm.expectRevert();
        baseWords.setWordBlocked(1, true);
    }

    /// test metadataLocked cannot be changed if metadata is locked
    function testMetadataLocked() public {
        vm.prank(owner);
        baseWords.lockMetadata();
        vm.prank(addr1);
        vm.expectRevert();
        baseWords.setWordBlocked(1, true);
    }

    /// test whitelisted addresses can mint when minting is disabled
    function testWhitelistedAddresses() public {
        vm.startPrank(owner);
        address[] memory users = new address[](1);
        users[0] = addr1;
        baseWords.setEarlyAccessList(users, true);
        baseWords.toggleMinting(); // Disable minting
        baseWords.setEarlyAccessEnabled();
        vm.stopPrank();
        vm.prank(addr1);
        string[] memory words = new string[](1);
        words[0] = "WORD1";
        baseWords.mint{value: mintPrice}(words);
        assertEq(baseWords.ownerOf(1), addr1);
    }

    /// test preMint
    function testPreMint() public {
        vm.prank(owner);
        baseWords.toggleMinting();
        vm.prank(owner);
        string[] memory words = new string[](1);
        words[0] = "WORD1";
        baseWords.preMint(owner, words);
        assertEq(baseWords.ownerOf(1), owner);

        /// test others cant preMint
        vm.prank(addr1);
        vm.expectRevert();
        string[] memory newWords = new string[](2);
        newWords[0] = "COLORFUL";
        newWords[1] = "VIBRANT";
        baseWords.preMint(addr1, newWords);
    }

    /// write a test to change stageTwoAddress
    function testChangeStageTwoAddress() public {
        vm.prank(owner);
        baseWords.setStageTwoAddress(addr1);
        assertEq(baseWords.stageTwoAddress(), addr1);
    }

    /// write a test to check mintedAmount is working
    function testMintedAmount() public {
        vm.startPrank(owner);
        address[] memory users = new address[](1);
        users[0] = addr1;
        baseWords.setEarlyAccessList(users, true);
        baseWords.toggleMinting();
        baseWords.setEarlyAccessEnabled();
        vm.stopPrank();

        vm.startPrank(addr1);
        for (uint256 i = 0; i < 10; i++) {
            string[] memory words = new string[](1);
            words[0] = string(abi.encodePacked("WORD", i.toString()));
            baseWords.mint{value: mintPrice}(words);
        }

        vm.expectRevert();
        string[] memory words1 = new string[](1);
        words1[0] = "WORD11";
        baseWords.mint{value: mintPrice}(words1);
        vm.stopPrank();
    }
}
