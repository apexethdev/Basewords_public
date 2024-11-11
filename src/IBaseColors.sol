// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBaseColors {
    function getAttributesAsJson(uint256 tokenId) external view returns (string memory);

    /// Base color Data
    struct ColorData {
        uint256 tokenId;
        bool isUsed;
        uint256 nameChangeCount;
        string[] modifiableTraits;
    }

    /// Base color sepolia struct
    // struct ColorData {
    //     uint256 tokenId;
    //     bool isUsed;
    //     uint256 nameChangeCount;
    // }

    function getColorData(string memory color) external view returns (ColorData memory);

    function tokenIdToColor(uint256 tokenId) external view returns (string memory);

    // New function to get the owner of a token ID
    function ownerOf(uint256 tokenId) external view returns (address);
}
