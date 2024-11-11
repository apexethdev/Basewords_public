// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {ERC721A} from "ERC721A/ERC721A.sol";

contract BASECOLORS is ERC721A, Ownable {
    using Strings for uint256;

    uint256 public currentTokenId;
    uint256 public mintPrice = 1000000000000000 wei; // Price per HEX value in wei
    uint256 public constant MAX_SUPPLY = 16777216; // Total number of valid HEX codes
    bool public isAdminPriceChangeEnabled = true; // Flag to allow mint price changes by admin, enabled by default
    bool public isAdminNameOverwriteEnabled = true; // Enable name overwrites by admin, enabled by default
    bool public isMintingEnabled = false; // Flag to enable minting, off by default

    struct ColorData {
        uint256 tokenId;
        bool isUsed;
        uint256 nameChangeCount;
        string[] modifiableTraits;
    }

    struct AttributeData {
        bool isUserModifiable;
        bool isEnabledForAllTokens;
    }

    mapping(string => ColorData) private colorData; // Maps HEX color to ColorData struct
    mapping(string => AttributeData) private attributeData; // Maps trait name to AttributeData struct
    mapping(uint256 => string) public tokenIdToColor; // Maps token ID to HEX color
    mapping(string => bool) internal isNameUsed; // Tracks if a name is already in use
    mapping(uint256 => mapping(string => string)) private tokenAttributes; // Nested mapping to store attribute key and value for each token
    mapping(uint256 => string[]) private tokenTraits; // Tracks attribute types for each token
    mapping(string => bool) public isUserModifiableAttribute; // Tracks whether an attribute can be modified by token owne

    /**
     * @dev This event emits when the admin updates the mint price.
     * @param newMintPrice The new price in wei.
     */
    event MintPriceChanged(uint256 newMintPrice);

    /**
     * @dev This event emits when a token is minted.
     * @param recipient The recipient of the token.
     * @param _tokenId The token ID of the minted token.
     * @param color The HEX code of the color being minted.
     * @param name The name of the color being minted.
     */
    event TokenMinted(
        address indexed recipient,
        uint256 indexed _tokenId,
        string color,
        string name
    );

    /**
     * @dev This event emits when tokens are batch minted in a single transaction.
     * @param recipient The recipient of the tokens.
     * @param colors The HEX codes of the colors being minted.
     * @param names The names of the colors being minted.
     */
    event TokensMinted(
        address indexed recipient,
        string[] colors,
        string[] names
    );

    /**
     * @dev This event emits when color's name is changed.
     * @param owner The token owner.
     * @param _tokenId The token ID being updated.
     * @param color The HEX code of the color being changed.
     * @param name The new name of the color.
     */
    event NameChanged(
        address indexed owner,
        uint256 indexed _tokenId,
        string color,
        string name
    );

    /**
     * @dev This event emits when a trait type is updated for a token by an admin.
     * @param _tokenId The token ID being updated.
     * @param keys The trait types being updated.
     * @param values The trait values being set.
     */
    event TokenAttributesUpdated(
        uint256 indexed _tokenId,
        string[] keys,
        string[] values
    );

    /**
     * @dev This event emits when a trait type is removed from a token by an admin.
     */
    event AttributeRemoved(uint256 indexed _tokenId, string traitType);

    /**
     * @dev This event emits when the metadata of a token is changed for use by third-party marketplaces.
     */
    event MetadataUpdate(uint256 _token);

    /**
     * @dev Contract constructor
     * Sets the initial values and initializes the contract.
     */
    constructor() ERC721A("Base Colors", "COLORS") Ownable(msg.sender) {}

    /**
     * @dev Mints a new token with a specified color and name.
     * @param color The HEX color of the token.
     * @param name The name associated with the color.
     * @param recipient The address that will receive the token.
     */
    function mint(
        string memory color,
        string memory name,
        address recipient
    ) public payable {
        require(
            msg.value >= mintPrice && msg.value % mintPrice == 0,
            "Incorrect ETH amount"
        );
        require(isMintingEnabled == true, "Minting must be enabled by admin");

        string memory upperColor = toUpper(color); // Enforce all caps nomenclature for HEX codes
        string memory normalizedName = normalizeString(name); // Enforce lowercase and no spacing for name comparisons

        require(currentTokenId < MAX_SUPPLY, "Minting would exceed max supply");
        require(isValidHex(upperColor), "Invalid HEX code provided");
        require(isValidName(name), "Invalid name provided");
        require(
            isMatchingHex(upperColor, normalizedName),
            "Name reserved for another HEX code"
        );
        require(!colorData[upperColor].isUsed, "HEX color already used");
        require(!isNameUsed[normalizedName], "Name already used");

        _safeMint(recipient, 1);

        // Initialize and set values in the struct
        string[] memory modifiableTraits = new string[](1);
        modifiableTraits[0] = "";
        colorData[upperColor] = ColorData({
            tokenId: currentTokenId,
            isUsed: true,
            nameChangeCount: 0,
            modifiableTraits: modifiableTraits
        });

        tokenIdToColor[currentTokenId] = upperColor;
        isNameUsed[normalizedName] = true;
        tokenAttributes[currentTokenId]["Color Name"] = name; // Set initial Color Name for token
        tokenTraits[currentTokenId].push("Color Name"); // All tokens are assigned a Color Name attribute

        emit TokenMinted(recipient, currentTokenId, upperColor, name);
        currentTokenId++;
    }

    /**
     * @dev Mints multiple tokens in a single transaction.
     * @param colors An array of HEX colors.
     * @param names An array of names corresponding to each color.
     * @param quantity The number of tokens to be minted.
     * @param recipient The address that will receive the tokens.
     */
    function mintBatch(
        string[] memory colors,
        string[] memory names,
        uint256 quantity,
        address recipient
    ) public payable {
        require(
            colors.length == names.length,
            "Colors and names must match in length"
        );
        require(isMintingEnabled == true, "Minting must be enabled by admin");
        require(colors.length == quantity, "Colors and quantity must match");
        require(msg.value >= mintPrice * quantity, "Incorrect ETH amount");
        require(
            currentTokenId + quantity <= MAX_SUPPLY,
            "Minting would exceed max supply"
        );

        uint256 startTokenId = currentTokenId; // Capture the start tokenId for the batch

        for (uint i; i < quantity; i++) {
            uint256 tokenId = startTokenId + i; // Use startTokenId for correct sequential IDs

            string memory upperColor = toUpper(colors[i]); // Ensure consistent capitalization
            string memory normalizedName = normalizeString(names[i]);
            require(isValidHex(upperColor), "Invalid HEX code provided");
            require(isValidName(names[i]), "Invalid name provided");
            require(
                isMatchingHex(upperColor, normalizedName),
                "Name reserved for another HEX code"
            );
            require(!colorData[upperColor].isUsed, "HEX code already used");
            require(!isNameUsed[normalizedName], "Name already used");

            // Initialize and set values in the struct
            string[] memory modifiableTraits = new string[](1);
            modifiableTraits[0] = "";
            colorData[upperColor] = ColorData({
                tokenId: tokenId,
                isUsed: true,
                nameChangeCount: 0,
                modifiableTraits: modifiableTraits
            });
            tokenIdToColor[tokenId] = upperColor;
            isNameUsed[normalizedName] = true;
            tokenAttributes[tokenId]["Color Name"] = names[i]; // Set initial Color Name for token
            tokenTraits[tokenId].push("Color Name"); // All tokens are assigned a Color Name attribute
        }

        _safeMint(recipient, quantity); // Batch minting uses startTokenId
        emit TokensMinted(recipient, colors, names);
        currentTokenId += quantity; // Increment currentTokenId by the quantity minted
    }

    /**
     * @dev Updates the name of a specific token.
     * @param tokenId The ID of the token to update.
     * @param newName The new name to associate with the token.
     */
    function setColorName(uint256 tokenId, string memory newName) public {
        string memory normalizedName = normalizeString(newName);
        string memory color = tokenIdToColor[tokenId];
        string memory upperColor = toUpper(color);

        require(ownerOf(tokenId) == msg.sender, "Caller is not token owner");
        require(isValidName(newName), "Invalid name provided");
        require(
            isMatchingHex(upperColor, normalizedName),
            "Name reserved for another HEX code"
        );
        require(!isNameUsed[normalizedName], "Name already used");

        string memory oldName = tokenAttributes[tokenId]["Color Name"];

        if (bytes(oldName).length != 0) {
            isNameUsed[normalizeString(oldName)] = false; // Free up the old name
        }

        tokenAttributes[tokenId]["Color Name"] = newName;
        colorData[upperColor].nameChangeCount++;
        isNameUsed[normalizedName] = true;
        emit NameChanged(ownerOf(tokenId), tokenId, upperColor, newName);
        emit MetadataUpdate(tokenId);
    }

    /**
     * @dev Batch updates the names of multiple tokens.
     * @param tokenIds An array of token IDs to update.
     * @param newNames An array of new names corresponding to each token ID.
     */
    function setColorNamesBatch(
        uint256[] memory tokenIds,
        string[] memory newNames
    ) public {
        require(
            tokenIds.length == newNames.length,
            "Token IDs and names length mismatch"
        );

        for (uint i; i < tokenIds.length; i++) {
            setColorName(tokenIds[i], newNames[i]); // Directly use the existing function
        }
    }

    /**
     * @dev Allows the user to update values for certain admin-enabled traits.
     * @param tokenId The token ID to update.
     * @param traitType The trait type to update.
     * @param value The trait value to update.
     */
    function updateTokenAttribute(
        uint256 tokenId,
        string memory traitType,
        string memory value
    ) public {
        require(
            keccak256(bytes(traitType)) != keccak256(bytes("Color Name")),
            "Cannot update Color Name through this function, use setColorName instead"
        );
        require(ownerOf(tokenId) == msg.sender, "Caller is not token owner");
        require(
            attributeData[traitType].isUserModifiable,
            "Updates not enabled by admin for this trait type"
        );

        bool isTraitModifiable = attributeData[traitType].isEnabledForAllTokens; // If false, check to see if given token ID is eligible
        if (!isTraitModifiable) {
            string memory color = tokenIdToColor[tokenId];
            for (
                uint i = 0;
                i < colorData[color].modifiableTraits.length;
                i++
            ) {
                if (
                    keccak256(bytes(traitType)) ==
                    keccak256(bytes(colorData[color].modifiableTraits[i]))
                ) {
                    isTraitModifiable = true;
                    break;
                }
            }
        }
        require(isTraitModifiable, "Trait not modifiable for this token");

        if (bytes(tokenAttributes[tokenId][traitType]).length == 0) {
            // If the key does not exist, add it to the tracking list
            tokenTraits[tokenId].push(traitType); // Keep track of attributeTypes used for given token ID
        }

        tokenAttributes[tokenId][traitType] = value;
        emit MetadataUpdate(tokenId);
    }


    /*---------------*/
    /*  PUBLIC VIEW  */
    /*---------------*/

    /**
     * @dev Retrieves the data associated with a specific color.
     * @param color The HEX color to query.
     * @return The ColorData struct associated with the color.
     */
    function getColorData(
        string memory color
    ) public view returns (ColorData memory) {
        string memory upperColor = toUpper(color);
        ColorData memory data = colorData[upperColor];
        require(data.isUsed, "Color not used");
        return data;
    }

    /**
     * @dev Retrieves the data associated with a specific color.
     * @param traitType The HEX color to query.
     * @return The ColorData struct associated with the color.
     */
    function getAttributeData(
        string memory traitType
    ) public view returns (AttributeData memory) {
        AttributeData memory data = attributeData[traitType];
        return data;
    }

    /**
     * @dev Validates if a given string is a valid HEX color.
     * @param hexString The string to validate.
     * @return True if the string is a valid HEX color, false otherwise.
     */
    function isValidHex(string memory hexString) public pure returns (bool) {
        bytes memory b = bytes(hexString);
        if (b.length != 7) return false; // Ensure HEX code includes the '#' and is 6 characters long
        if (b[0] != bytes1("#")) return false;
        for (uint i = 1; i < b.length; i++) {
            if (!isHexCharacter(b[i])) return false;
        }
        return true;
    }

    /**
     * @dev Checks if a name is already in use.
     * @param name The name to check.
     * @return True if the name is already in use, false otherwise.
     */
    function isNameTaken(string memory name) public view returns (bool) {
        return isNameUsed[normalizeString(name)];
    }

    /**
     * @dev Returns the token URI for a given token ID.
     * @param tokenId The ID of the token to query.
     * @return The token URI as a string.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            ownerOf(tokenId) != address(0),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return generateTokenURI(tokenId);
    }

    /**
     * @dev Returns a range of all minted colors to support pagination.
     * @param start The index of the first token to start retrieving colors from.
     * @param end The index of the last token to retrieve colors, exclusive.
     * @return colors An array containing the colors of tokens in the specified range.
     */
    function getMintedColorsRange(
        uint256 start,
        uint256 end
    ) public view returns (string[] memory) {
        require(start < end, "Start index must be less than end index");
        require(end <= currentTokenId, "End index out of bounds");

        uint256 rangeSize = end - start;
        string[] memory colors = new string[](rangeSize);
        for (uint256 i = 0; i < rangeSize; i++) {
            colors[i] = tokenIdToColor[start + i];
        }
        return colors;
    }

    /**
     * @dev Accepts a tokenId and returns any relevant attributes in a json format.
     * @param tokenId The ID of the token.
     */
    function getAttributesAsJson(
        uint256 tokenId
    ) public view returns (string memory) {
        string[] memory keys = tokenTraits[tokenId];
        uint256 length = keys.length;

        // Start JSON array
        string memory json = "[";

        for (uint256 i = 0; i < length; i++) {
            string memory key = keys[i];
            string memory value = tokenAttributes[tokenId][key];

            // Append JSON object for attribute
            json = string(
                abi.encodePacked(
                    json,
                    "{",
                    '"trait_type":"',
                    key,
                    '",',
                    '"value":"',
                    value,
                    '"',
                    "}",
                    (i < length - 1 ? "," : "") // Add comma except for last item
                )
            );
        }

        // Close JSON array
        json = string(abi.encodePacked(json, "]"));

        return json;
    }

    /*---------------*/
    /*    INTERNAL   */
    /*---------------*/

    /**
     * @dev Generates a fully onchain token URI as a base64 encoded string with no external dependencies.
     * @param tokenId The tokenId being called.
     */
    function generateTokenURI(
        uint256 tokenId
    ) internal view returns (string memory) {
        string memory color = tokenIdToColor[tokenId];

        // Construct SVG
        string memory svg = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" fill="',
                        color,
                        '"/></svg>'
                    )
                )
            )
        );

        string memory attributesJson = getAttributesAsJson(tokenId);

        // Encode JSON metadata with Color Name as a default attribute
        string memory json = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            color,
                            '","description":"Base Colors is the NFT collection for every color on the internet."',
                            ',"image":"data:image/svg+xml;base64,',
                            svg,
                            '","attributes":',
                            attributesJson,
                            "}"
                        )
                    )
                )
            )
        );

        return json;
    }

    /**
     * @dev Helper function to determine if a character is a valid HEX character.
     * @param b The character to validate.
     * @return True if the character is valid, false otherwise.
     */
    function isHexCharacter(bytes1 b) internal pure returns (bool) {
        return
            (b >= 0x30 && b <= 0x39) || // 0-9
            (b >= 0x41 && b <= 0x46) || // A-F
            (b >= 0x61 && b <= 0x66); // a-f
    }

    /**
     * @dev Returns a boolean to check that is the name is a 6-digit hexidecimal, it matches its color's HEX code.
     * @param color The HEX color in uppercase.
     * @param name The normalized name.
     */
    function isMatchingHex(
        string memory color,
        string memory name
    ) internal pure returns (bool) {
        string memory prefixedName = toUpper(
            string(abi.encodePacked("#", name))
        ); // Ensure name is prefixed with a # for matching
        if (isValidHex(prefixedName)) {
            // If the name is a valid hex code, it must be the same as the color being minted
            return keccak256(bytes(prefixedName)) == keccak256(bytes(color));
        }
        // If it's not a hex code, it's valid
        return true;
    }

    /**
     * @dev Converts a string to uppercase.
     * @param str The string to convert.
     * @return The uppercase string.
     */
    function toUpper(string memory str) private pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bUpper = new bytes(bStr.length);
        for (uint256 i; i < bStr.length; i++) {
            // Uppercase each hexadecimal character
            if (bStr[i] >= "a" && bStr[i] <= "z") {
                bUpper[i] = bytes1(uint8(bStr[i]) - 32);
            } else {
                bUpper[i] = bStr[i];
            }
        }
        return string(bUpper);
    }

    /**
     * @dev Normalizes a string by removing spaces and converting to lowercase.
     * @param str The string to normalize.
     * @return The normalized string.
     */
    function normalizeString(
        string memory str
    ) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);

        for (uint256 i = 0; i < bStr.length; i++) {
            // Check if the character is an uppercase letter (A-Z)
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // Convert to lowercase by adding 32 to the ASCII value
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                // If not an uppercase letter, keep the character as is
                bLower[i] = bStr[i];
            }
        }

        // Return the normalized string
        return string(bLower);
    }

    /**
     * @dev Checks if a name is valid.
     * @param str The name to check.
     * @return True if the name is valid, false otherwise.
     */
    function isValidName(string memory str) internal pure returns (bool) {
        bytes memory bStr = bytes(str);
        if (bStr.length == 0 || bStr.length > 32) {
            return false; // Empty string is not valid
        }
        for (uint256 i = 0; i < bStr.length; i++) {
            bytes1 char = bStr[i];
            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x41 && char <= 0x5A) && // A-Z
                !(char >= 0x61 && char <= 0x7A) // a-z
            ) {
                return false;
            }
        }
        return true;
    }
}