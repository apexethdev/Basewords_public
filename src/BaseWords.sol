// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721A} from "ERC721A/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "./base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {WordData, WordVerifyStatus, IBaseColors, IERC4906} from "./WordData.sol";

/**
 * @title   --- Base Words - Mint unique words on Base
 * @author  --- Project by Deebee.eth
 * @dev     --- Contract by Apex777.eth
 * @notice  --- www.basewords.xyz
 */
contract BaseWords is Ownable, ReentrancyGuard, ERC721A, WordData, IERC4906 {
    using Strings for uint256;

    /// mint settings - public mint
    bool public mintEnabled = false;
    uint256 public mintPrice = 0.001 ether;

    /// mint settings - early access mint
    bool public earlyAccessEnabled = false;
    mapping(address => bool) public earlyAccessList;
    mapping(address => uint256) public mintedAmount;
    uint256 public maxMintAmount = 10;

    /// mint settings - team mints
    bool public teamMintEnabled = false;
    mapping(address => bool) public teamWallets;
    mapping(address => uint256) public teamMintedAmount;
    uint256 public maxTeamMintAmount = 10;

    /// metadata lock
    bool public metadataLocked = false;

    /// payment split
    address private splitAddress = payable(0xc897851CD0B04AFC8c8467594acb9fc60A39B9fe);

    /// events
    event Mint(address indexed minter, uint256 tokenId);
    event ColorsUpdated(uint256 indexed tokenId, string textColor, string backgroundColor);
    event ColorsInverted(uint256 indexed tokenId, bool isInverted);
    event ColorsReset(uint256 indexed tokenId);
    event WordBlocked(uint256 indexed tokenId, bool blocked);

    constructor() Ownable(msg.sender) ERC721A("BaseWords", "WORDS") {
        baseColorsAddress = 0x7Bc1C072742D8391817EB4Eb2317F98dc72C61dB;
        baseColors = IBaseColors(baseColorsAddress);
    }

    /**
     * @dev Start token ID for the collection is 1.
     */
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /**
     * @dev Mints a token with the given words.
     */
    function mint(string[] memory words) external payable {
        uint256 cost = mintPrice;
        uint256 tokenId = _nextTokenId();

        if (earlyAccessList[msg.sender] && earlyAccessEnabled) {
            require(mintedAmount[msg.sender] < maxMintAmount, "Early access mint limit reached");
            mintedAmount[msg.sender]++;
        } else {
            require(mintEnabled, "Mint not started");
        }

        require(msg.value == cost, "Please send the exact ETH amount");

        (bool isValid,) = wordVerify(words);
        require(isValid, "Word verification failed");

        _storeWords(words);

        (bool success,) = splitAddress.call{value: cost}("");
        require(success, "Transfer failed.");

        _safeMint(msg.sender, 1);
        emit Mint(msg.sender, tokenId);
    }

    /**
     * @dev Verifies the given words.
     */
    function wordVerify(string[] memory words) public view returns (bool, WordVerifyStatus) {
        if (words.length == 0 || words.length > 3) {
            return (false, WordVerifyStatus.InvalidWordCount);
        }

        for (uint256 i = 0; i < words.length; i++) {
            bytes memory wordBytes = bytes(words[i]);
            uint256 length = wordBytes.length;
            if (length < 1 || length > 16) {
                return (false, WordVerifyStatus.InvalidWordLength);
            }

            for (uint256 j = 0; j < length; j++) {
                bytes1 char = wordBytes[j];
                if (
                    !(char >= 0x30 && char <= 0x39) // 0-9
                        && !(char >= 0x41 && char <= 0x5A) // A-Z
                ) {
                    return (false, WordVerifyStatus.InvalidCharacter);
                }
            }
        }

        bytes32 hash =
            keccak256(abi.encodePacked(words[0], "|", words.length > 1 ? words[1] : "", "|", words.length > 2 ? words[2] : ""));
        if (usedCombinations[hash]) {
            return (false, WordVerifyStatus.CombinationUsed);
        }

        return (true, WordVerifyStatus.Success);
    }

    /**
     * @dev Stores the given words.
     */
    function _storeWords(string[] memory words) internal {
        uint256 tokenId = _nextTokenId();

        bytes32 hash =
            keccak256(abi.encodePacked(words[0], "|", words.length > 1 ? words[1] : "", "|", words.length > 2 ? words[2] : ""));

        // Mark this combination as used
        usedCombinations[hash] = true;

        // Store token data
        tokenData[tokenId] = TokenData({
            word1: words[0],
            word2: words.length > 1 ? words[1] : "",
            word3: words.length > 2 ? words[2] : "",
            backgroundColor: "#FFFFFF",
            textColor: "#0052FF",
            wordCount: words.length,
            isTextColored: false,
            isBackgroundColored: false,
            isInverted: false
        });
    }

    /**
     * @dev Returns the token URI for the given token ID.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory svg = _generateSVG(tokenId);
        string memory encodedSvg = Base64.encode(bytes(svg));

        string memory json = string(
            abi.encodePacked(
                '{"name": "BaseWords #',
                Strings.toString(tokenId),
                '", "description": "Base Words are the building blocks for an infinite onchain art and storytelling experiment. Mint unique words on base. Add your unique base colors. Build a library and become part of the evolving metastory.", "image": "data:image/svg+xml;base64,',
                encodedSvg,
                '", "attributes": ',
                buildAttributesJSON(tokenId),
                "}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /**
     * @dev Builds the attributes JSON for the given token ID.
     */
    function buildAttributesJSON(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        // Check if the token is blocked
        if (wordBlocked[tokenId]) {
            return '[{"trait_type":"Blocked","value":"true"}]';
        }

        TokenData memory data = tokenData[tokenId];
        string memory attributes = "[";

        if (bytes(data.word1).length > 0) {
            attributes = string(abi.encodePacked(attributes, '{"trait_type":"Word #1","value":"', data.word1, '"}'));
        }
        if (bytes(data.word2).length > 0) {
            attributes = string(abi.encodePacked(attributes, ',{"trait_type":"Word #2","value":"', data.word2, '"}'));
        }
        if (bytes(data.word3).length > 0) {
            attributes = string(abi.encodePacked(attributes, ',{"trait_type":"Word #3","value":"', data.word3, '"}'));
        }

        attributes = string(
            abi.encodePacked(
                attributes, ',{"trait_type":"Word Count","value":"', Strings.toString(data.wordCount), '"}'
            )
        );

        if (data.isBackgroundColored && data.isTextColored) {
            attributes = string(abi.encodePacked(attributes, ',{"trait_type":"Fully Colored","value":"Yes"}'));
        } else {
            attributes = string(abi.encodePacked(attributes, ',{"trait_type":"Fully Colored","value":"No"}'));
        }

        if (data.isBackgroundColored) {
            attributes = string(
                abi.encodePacked(attributes, ',{"trait_type":"Background HEX","value":"', data.backgroundColor, '"}')
            );

            string memory colorNameBG = getColorName(data.backgroundColor);
            attributes = string(
                abi.encodePacked(attributes, ',{"trait_type":"Background Color Name","value":"', colorNameBG, '"}')
            );
        } else {
            if (data.isInverted) {
                attributes =
                    string(abi.encodePacked(attributes, ',{"trait_type":"Background HEX","value":"Default Blue"}'));
            } else {
                attributes =
                    string(abi.encodePacked(attributes, ',{"trait_type":"Background HEX","value":"Default White"}'));
            }
        }

        if (data.isTextColored) {
            attributes =
                string(abi.encodePacked(attributes, ',{"trait_type":"Word HEX","value":"', data.textColor, '"}'));

            string memory colorNameW = getColorName(data.textColor);
            attributes =
                string(abi.encodePacked(attributes, ',{"trait_type":"Word Color Name","value":"', colorNameW, '"}'));
        } else {
            if (data.isInverted) {
                attributes = string(abi.encodePacked(attributes, ',{"trait_type":"Word HEX","value":"Default White"}'));
            } else {
                attributes = string(abi.encodePacked(attributes, ',{"trait_type":"Word HEX","value":"Default Blue"}'));
            }
        }

        if (stageTwoAddress == ownerOf(tokenId)) {
            attributes = string(abi.encodePacked(attributes, ',{"trait_type":"Staked","value":"Yes"}'));
        }

        attributes = string(abi.encodePacked(attributes, "]"));

        return attributes;
    }

    /**
     * @dev Builds the SVG for the given token ID.
     */
    function buildSVG(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        string memory svg = _generateSVG(tokenId);
        return svg;
    }

    /// Color setters

    /**
     * @dev Updates the background color for the given token ID.
     */
    function updateBackgroundColor(uint256 tokenId, uint256 colorTokenBackground) public {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the owner");
        require(!wordBlocked[tokenId], "Token is blocked");

        TokenData storage data = tokenData[tokenId];

        require(
            baseColors.ownerOf(colorTokenBackground) == msg.sender, "Caller does not own the background color token"
        );
        data.backgroundColor = baseColors.tokenIdToColor(colorTokenBackground);
        data.isBackgroundColored = true;
        colorChangeCount++;

        emit MetadataUpdate(tokenId);
        emit ColorsUpdated(tokenId, data.textColor, data.backgroundColor);
    }

    /**
     * @dev Updates the word color for the given token ID.
     */
    function updateWordColor(uint256 tokenId, uint256 colorTokenWord) public {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the owner");
        require(!wordBlocked[tokenId], "Token is blocked");

        TokenData storage data = tokenData[tokenId];

        require(baseColors.ownerOf(colorTokenWord) == msg.sender, "Caller does not own the word color token");
        data.textColor = baseColors.tokenIdToColor(colorTokenWord);
        data.isTextColored = true;
        colorChangeCount++;

        emit MetadataUpdate(tokenId);
        emit ColorsUpdated(tokenId, data.textColor, data.backgroundColor);
    }

    /**
     * @dev Updates all colors for the given token ID.
     */
    function updateAllColors(uint256 tokenId, uint256 colorTokenBackground, uint256 colorTokenWord) public {
        updateBackgroundColor(tokenId, colorTokenBackground);
        updateWordColor(tokenId, colorTokenWord);
    }

    /**
     * @dev Inverts the colors for the given token ID.
     */
    function invertDefaultColors(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the owner");
        require(!wordBlocked[tokenId], "Token is blocked");

        /// check if both colors are not set
        require(
            !tokenData[tokenId].isBackgroundColored && !tokenData[tokenId].isTextColored,
            "Both colors must be unset to invert"
        );
        TokenData storage data = tokenData[tokenId];

        if (!data.isInverted) {
            data.textColor = "#FFFFFF";
            data.backgroundColor = "#0052FF";

            data.isInverted = true;
        } else {
            data.textColor = "#0052FF";
            data.backgroundColor = "#FFFFFF";
            data.isInverted = false;
        }

        emit MetadataUpdate(tokenId);
        emit ColorsInverted(tokenId, data.isInverted);
    }

    /**
     * @dev Resets the colors for the given token ID.
     */
    function resetColors(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the owner");
        require(!wordBlocked[tokenId], "Token is blocked");

        TokenData storage data = tokenData[tokenId];

        data.textColor = "#0052FF";
        data.isTextColored = false;
        data.backgroundColor = "#FFFFFF";
        data.isBackgroundColored = false;
        data.isInverted = false;
        emit MetadataUpdate(tokenId);
        emit ColorsReset(tokenId);
    }

    /// admin functions

    /**
     * @dev team member mint - can mint without cost
     */
    function teamMint(string[] memory words) external {
        uint256 tokenId = _nextTokenId();

        require(teamMintEnabled, "Team mint is not enabled");
        require(teamWallets[msg.sender], "Caller is not a team wallet");
        require(teamMintedAmount[msg.sender] < maxTeamMintAmount, "Mint limit reached");
        teamMintedAmount[msg.sender]++;

        (bool isValid,) = wordVerify(words);
        require(isValid, "Word verification failed");

        _storeWords(words);

        _safeMint(msg.sender, 1);
        emit Mint(msg.sender, tokenId);
    }

    /**
     * @dev Sets the whitelisted addresses for early access.
     */
    function setEarlyAccessList(address[] memory _address, bool isWhitelisted) external onlyOwner {
        for (uint256 i = 0; i < _address.length; i++) {
            earlyAccessList[_address[i]] = isWhitelisted;
        }
    }

    /**
     * @dev Sets the early access enabled state.
     */
    function setEarlyAccessEnabled() external onlyOwner {
        earlyAccessEnabled = !earlyAccessEnabled;
    }

    /**
     * @dev Toggles the minting state.
     */
    function toggleMinting() external onlyOwner {
        mintEnabled = !mintEnabled;
    }

    /**
     * @dev Sets the team wallets.
     */
    function setTeamWallets(address _address, bool isTeamWallet) external onlyOwner {
        teamWallets[_address] = isTeamWallet;
    }

    /**
     * @dev Toggles the team minting state.
     */
    function toggleTeamMinting() external onlyOwner {
        teamMintEnabled = !teamMintEnabled;
    }

    /**
     * @dev Sets the word blocked state for the given token ID.
     * Can be bricked with lockMetadata()
     */
    function setWordBlocked(uint256 tokenId, bool blocked) external onlyOwner {
        require(!metadataLocked, "Metadata is locked");
        wordBlocked[tokenId] = blocked;
        emit MetadataUpdate(tokenId);
        emit WordBlocked(tokenId, blocked);
    }

    /**
     * @dev Locks the metadata and stop tokens from being blocked
     */
    function lockMetadata() external onlyOwner {
        metadataLocked = true;
    }

    /**
     * @dev Sets the stage two address.
     */
    function setStageTwoAddress(address _stageTwoAddress) external onlyOwner {
        stageTwoAddress = _stageTwoAddress;
    }

    /**
     * @dev Pre-mints a token with the given words before launch.
     */
    function preMint(address to, string[] memory words) external onlyOwner {
        require(!mintEnabled, "Mint is enabled - no pre-mints");
        uint256 tokenId = _nextTokenId();

        (bool isValid,) = wordVerify(words);
        require(isValid, "Word verification failed");

        _storeWords(words);

        _safeMint(to, 1);
        emit Mint(to, tokenId);
    }

    /**
     * @dev Withdraws the contract balance to the owner.
     * shouldnt be needed as we are using a split contract for payments
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        (bool success,) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed.");
    }

    /// override functions

    /**
     * @dev Emits metadata update events for the given token IDs.
     */
    function _afterTokenTransfers(address, address, uint256 startTokenId, uint256 quantity) internal virtual override {
        for (uint256 i = 0; i < quantity; i++) {
            emit MetadataUpdate(startTokenId + i);
        }
    }
}