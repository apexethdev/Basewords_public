// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IBaseColors} from "./IBaseColors.sol";

/**
 * @dev Interface for metadata update events.
 */
interface IERC4906 {
    event MetadataUpdate(uint256 _tokenId);
}

/**
 * @dev Enum for word verification status.
 */
enum WordVerifyStatus {
    Success,
    InvalidWordCount,
    InvalidWordLength,
    InvalidCharacter,
    CombinationUsed
}

/**
 * @dev Helper contract for storing word data.
 */
contract WordData {
    using Strings for uint256;

    uint256 public colorChangeCount;

    /**
     * @dev Address for stage two.
     */
    address public stageTwoAddress = 0x7777777777777777777777777777777777777777;

    /**
     * @dev Address for base colors contract.
     */
    address public baseColorsAddress;
    IBaseColors internal baseColors;

    /**
     * @dev SVG for blocked tokens.
     */
    string internal blockedSvg =
        unicode'<svg width="600" height="600" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#FFFFFF" /><text x="50%" y="50%" font-family="Helvetica, sans-serif" font-weight="600" font-size="46" fill="#000000" text-anchor="middle" dy=".3em">⛔</text></svg>';

    string internal svgEnd = "</svg>";

    /**
     * @dev Struct for token data.
     */
    struct TokenData {
        string word1;
        string word2;
        string word3;
        string backgroundColor;
        string textColor;
        bool isTextColored;
        bool isBackgroundColored;
        bool isInverted;
        uint256 wordCount;
    }

    /**
     * @dev Mappings for token data, word blocked status, and used combinations.
     */
    mapping(uint256 => TokenData) public tokenData;
    mapping(uint256 => bool) public wordBlocked;
    mapping(bytes32 => bool) public usedCombinations;

    /**
     * @dev Function to get token data.
     */
    function getTokenData(uint256 tokenId) public view returns (TokenData memory) {
        return tokenData[tokenId];
    }

    /**
     * @dev Internal function to generate SVG for a given token.
     */
    function _generateSVG(uint256 tokenId) internal view returns (string memory) {
        // Check if the token is blocked
        if (wordBlocked[tokenId]) {
            return blockedSvg;
        }

        TokenData memory data = tokenData[tokenId];
        string memory wordsSvg = "";

        if (bytes(data.word1).length > 0 && bytes(data.word2).length == 0 && bytes(data.word3).length == 0) {
            // 1 word
            wordsSvg = string(abi.encodePacked(wordsSvg, _generateWordSVG(data.word1, 50, data.textColor)));
        } else if (bytes(data.word1).length > 0 && bytes(data.word2).length > 0 && bytes(data.word3).length == 0) {
            // 2 words
            wordsSvg = string(abi.encodePacked(wordsSvg, _generateWordSVG(data.word1, 45, data.textColor)));
            wordsSvg = string(abi.encodePacked(wordsSvg, _generateWordSVG(data.word2, 55, data.textColor)));
        } else if (bytes(data.word1).length > 0 && bytes(data.word2).length > 0 && bytes(data.word3).length > 0) {
            // 3 words
            wordsSvg = string(abi.encodePacked(wordsSvg, _generateWordSVG(data.word1, 40, data.textColor)));
            wordsSvg = string(abi.encodePacked(wordsSvg, _generateWordSVG(data.word2, 50, data.textColor)));
            wordsSvg = string(abi.encodePacked(wordsSvg, _generateWordSVG(data.word3, 60, data.textColor)));
        }

        string memory svgStartWithColor = string(
            abi.encodePacked(
                '<svg width="600" height="600" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="',
                data.backgroundColor,
                '" />'
            )
        );
        // styling

        return string(abi.encodePacked(svgStartWithColor, wordsSvg, svgEnd));
    }

    /**
     * @dev Internal function to generate SVG snippet for a single word.
     */
    function _generateWordSVG(string memory word, uint256 yPercentage, string memory textColor)
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '<text x="50%" y="',
                Strings.toString(yPercentage),
                '%" font-family="Helvetica, sans-serif" font-weight="600" font-size="46" fill="',
                textColor,
                '" text-anchor="middle" dy=".3em">',
                word,
                "</text>"
            )
        );
    }

    /**
     * @dev Function to get color name from hex.
     * This function is used to get the color name from the base colors contract.
     * If not found, it returns the hex color.
     */
    function getColorName(string memory colorhex) public view returns (string memory) {
        try baseColors.getColorData(colorhex) returns (IBaseColors.ColorData memory colorData) {
            // Start finding the color name
            // Get the attributes JSON string for the color
            string memory attributes = baseColors.getAttributesAsJson(colorData.tokenId);

            // Extracting the color name from the attributes JSON string
            bytes memory attributesBytes = bytes(attributes);
            bytes memory colorNameKey = bytes('"trait_type":"Color Name","value":"');
            bytes memory endKey = bytes('"}');

            // Finding the start position of the color name
            uint256 start = 0;
            for (uint256 i = 0; i < attributesBytes.length - colorNameKey.length; i++) {
                bool ismatched = true;
                for (uint256 j = 0; j < colorNameKey.length; j++) {
                    if (attributesBytes[i + j] != colorNameKey[j]) {
                        ismatched = false;
                        break;
                    }
                }
                if (ismatched) {
                    start = i + colorNameKey.length;
                    break;
                }
            }

            // Finding the end position of the color name
            uint256 end = start;
            for (uint256 i = start; i < attributesBytes.length - endKey.length; i++) {
                bool ismatched = true;
                for (uint256 j = 0; j < endKey.length; j++) {
                    if (attributesBytes[i + j] != endKey[j]) {
                        ismatched = false;
                        break;
                    }
                }
                if (ismatched) {
                    end = i;
                    break;
                }
            }

            // Extracting the color name
            bytes memory colorNameBytes = new bytes(end - start);
            for (uint256 i = 0; i < end - start; i++) {
                colorNameBytes[i] = attributesBytes[start + i];
            }

            return (string(colorNameBytes));
        } catch {
            // If the call to getColorData fails, color not minted. return the hex color.
            /// if
            return colorhex;
        }
    }
}
