// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin Contracts
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/// --------------------------------------------------------------------------
/// Interfaces for Trait Contracts
/// --------------------------------------------------------------------------
interface IFrogsBackdrop {
    function getBackdropData(uint) external view returns (string memory);
    function getBackdropTrait(uint) external view returns (string memory);
}

interface IFrogsOneOfOne {
    function getOneOfOneData(uint) external view returns (bytes memory);
    function getOneOfOneTrait(uint) external view returns (string memory);
}

interface IFrogsBody {
    function getBodyData(uint) external view returns (bytes memory);
    function getBodyTrait(uint) external view returns (string memory);
}

interface IFrogsHats {
    function getHatsData(uint) external view returns (bytes memory);
    function getHatsTrait(uint) external view returns (string memory);
}

interface IFrogsEyesA {
    function getEyesAData(uint) external view returns (bytes memory);
    function getEyesATrait(uint) external view returns (string memory);
}

interface IFrogsEyesB {
    function getEyesBData(uint) external view returns (bytes memory);
    function getEyesBTrait(uint) external view returns (string memory);
}

interface IFrogsMouth {
    function getMouthData(uint) external view returns (bytes memory);
    function getMouthTrait(uint) external view returns (string memory);
}

interface IFrogsFeet {
    function getFeetData(uint) external view returns (bytes memory);
    function getFeetTrait(uint) external view returns (string memory);
}

/// --------------------------------------------------------------------------
/// Interface for the Old HyperFrogs Contract
/// --------------------------------------------------------------------------
interface IHyperFrogs {
    function ownerOf(uint256 tokenId) external view returns (address);
    function burn(uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function buildSVG(uint256 tokenId) external view returns (string memory);
    function tokenTraits(uint256 tokenId) external view returns (
        bool oneOfOne,
        uint oneOfOneIndex,
        uint backdrop,
        uint hat,
        uint eyesIndex,
        bool eyesIsA,
        uint mouth,
        uint body,
        uint feet
    );
}

/// --------------------------------------------------------------------------
/// HyperFrogsV2 Migration Contract using ERC721 and AccessControl
/// --------------------------------------------------------------------------
contract HyperFrogsV2 is ERC721, AccessControl, Pausable, ReentrancyGuard, ERC2981 {
    using Strings for uint256;
    uint256 public totalMigrated;
    
    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------    
    event TokenMigrated(address indexed owner, uint256 indexed tokenId, uint256 migrationBatch);

    // -----------------------------------------------------------------------
    // Struct & State Variables
    // -----------------------------------------------------------------------
    struct TraitStruct {
        bool oneOfOne;
        uint oneOfOneIndex;
        uint backdrop;
        uint hat;
        uint eyesIndex;
        bool eyesIsA;
        uint mouth;
        uint body;
        uint feet;
    }

    // -----------------------------------------------------------------------
    // Custom Errors
    // -----------------------------------------------------------------------
    error TokenAlreadyMigrated(uint256 tokenId);
    error NotOwnerOfOldNFT(uint256 tokenId, address actual, address sender);
    error NoTokenIDsProvided();
    error BatchSizeToLarge();
    error TokenNotMigratedYet(uint256 tokenId);

    IHyperFrogs public oldContract;
    mapping(uint256 => bool) public claimed;
    mapping(uint256 => TraitStruct) public tokenTraits;

    // Trait contract references – reuse the same contracts as in the original
    IFrogsBackdrop public frogsBackdrop;
    IFrogsOneOfOne public frogsOneOfOne;
    IFrogsBody public frogsBody;
    IFrogsHats public frogsHats;
    IFrogsEyesA public frogsEyesA;
    IFrogsEyesB public frogsEyesB;
    IFrogsMouth public frogsMouth;
    IFrogsFeet public frogsFeet;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event TokenMigrated(address indexed owner, uint256 indexed tokenId);

    // Optional debug event to help with troubleshooting ownerOf values
    event DebugOwner(address actualOwner);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(
        address _oldContract,
        address _frogsBackdrop,
        address _frogsOneOfOne,
        address _frogsBody,
        address _frogsHats,
        address _frogsEyesA,
        address _frogsEyesB,
        address _frogsMouth,
        address _frogsFeet
    )
        ERC721("Hyper Frogs", "HYF2")
        ERC2981()
    {
        require(_oldContract != address(0), "Invalid old contract address");
        oldContract = IHyperFrogs(_oldContract);
        frogsBackdrop = IFrogsBackdrop(_frogsBackdrop);
        frogsOneOfOne = IFrogsOneOfOne(_frogsOneOfOne);
        frogsBody = IFrogsBody(_frogsBody);
        frogsHats = IFrogsHats(_frogsHats);
        frogsEyesA = IFrogsEyesA(_frogsEyesA);
        frogsEyesB = IFrogsEyesB(_frogsEyesB);
        frogsMouth = IFrogsMouth(_frogsMouth);
        frogsFeet = IFrogsFeet(_frogsFeet);
        _setDefaultRoyalty(msg.sender, 350);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // -----------------------------------------------------------------------
    // ERC2981, ERC721, and AccessControl Interface Support
    // -----------------------------------------------------------------------
    /**
     * @notice Override supportsInterface to combine ERC721, ERC2981, and AccessControl interfaces.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981, AccessControl) returns (bool) {
        return ERC721.supportsInterface(interfaceId) ||
               ERC2981.supportsInterface(interfaceId) ||
               AccessControl.supportsInterface(interfaceId);
    }

    // -----------------------------------------------------------------------
    // Migration Functionality
    // -----------------------------------------------------------------------
    /**
     * @notice Batch claim (migrate) multiple NFTs at once.
     * Requirements:
     * - Caller must be owner of each token in the old contract.
     * - Each token must not have been migrated before.
     * - The contract must not be paused.
     */
    function batchClaim(uint256[] calldata tokenIds) external whenNotPaused nonReentrant {
        uint256 length = tokenIds.length;
        uint256 batchId = totalMigrated; // Use as a batch identifier
        if (length == 0) revert NoTokenIDsProvided();
        if (length > 20) revert BatchSizeToLarge();

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds[i];
            if (claimed[tokenId]) revert TokenAlreadyMigrated(tokenId);
            address actualOwner = oldContract.ownerOf(tokenId);
            if (actualOwner != msg.sender) revert NotOwnerOfOldNFT(tokenId, actualOwner, msg.sender);

            // Retrieve traits from the old contract using its public tokenTraits mapping
            (
                bool oneOfOne,
                uint oneOfOneIndex,
                uint backdrop,
                uint hat,
                uint eyesIndex,
                bool eyesIsA,
                uint mouth,
                uint body,
                uint feet
            ) = oldContract.tokenTraits(tokenId);

            tokenTraits[tokenId] = TraitStruct({
                oneOfOne: oneOfOne,
                oneOfOneIndex: oneOfOneIndex,
                backdrop: backdrop,
                hat: hat,
                eyesIndex: eyesIndex,
                eyesIsA: eyesIsA,
                mouth: mouth,
                body: body,
                feet: feet
            });

            // Mint the NFT with the same tokenId
            _safeMint(msg.sender, tokenId);

            // Mark token as claimed after minting succeeds
            claimed[tokenId] = true;
            totalMigrated++;
            emit TokenMigrated(msg.sender, tokenId, batchId);

            // Attempt to burn the old NFT; if burn fails, transfer it to the old contract's address (lockup)
            try oldContract.burn(tokenId) {
                // Burn succeeded.
            } catch {
                oldContract.transferFrom(msg.sender, address(oldContract), tokenId);
            }

            emit TokenMigrated(msg.sender, tokenId);
        }
    }

    /**
     * @notice Check the migration status of multiple tokens.
     * Returns an array of booleans indicating whether each token has been migrated.
     */
    function checkMigrationStatus(uint256[] calldata tokenIds) external view returns (bool[] memory statuses) {
        statuses = new bool[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            statuses[i] = claimed[tokenIds[i]];
        }
        return statuses;
    }

    // -----------------------------------------------------------------------
    // SVG & Metadata Generation Functions
    // -----------------------------------------------------------------------
    /**
     * @notice Returns the tokenURI for a given tokenId.
     * Rebuilds the on-chain SVG and metadata exactly as in the original contract.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory image = buildSVG(tokenId);
        string memory base64Image = Base64.encode(bytes(image));
        string memory json = string(
            abi.encodePacked(
                '{"name": "Hyper Frog #', tokenId.toString(), '",',
                '"description": "Hyper Frogs are pure ASCII art frogs and live 100% onchain on Hyperliquid.",',
                '"attributes": [', _getFrogTraits(tokenId), '],',
                '"image": "data:image/svg+xml;base64,', base64Image, '"}'
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /**
     * @notice Rebuilds the on-chain SVG using stored traits.
     */
    
    function buildSVG(uint tokenId) public view returns (string memory) {
        if (!claimed[tokenId]) revert TokenNotMigratedYet(tokenId);
        TraitStruct memory traits = tokenTraits[tokenId];

        if (traits.oneOfOne) {
            return string(
                abi.encodePacked(
                    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 90 90" shape-rendering="crispEdges" width="512" height="512">',
                    '<style>',
                    'svg {',
                        'width: 100%;',
                        'height: 100%;',
                        'margin: 0;',
                        'padding: 0;',
                        'overflow: hidden;',
                        'display: flex;',
                        'justify-content: center;',
                        'background:', frogsBackdrop.getBackdropData(traits.backdrop), ';',
                    '}',
                    '</style>',
                    '<rect width="90" height="90" fill="', frogsBackdrop.getBackdropData(traits.backdrop), '"/>',
                    _getSVGTraitData(frogsOneOfOne.getOneOfOneData(traits.oneOfOneIndex)),
                    '</svg>'
                )
            );
        }

        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 90 90" shape-rendering="crispEdges" width="512" height="512">',
                '<style>',
                'svg {',
                    'width: 100%;',
                    'height: 100%;',
                    'margin: 0;',
                    'padding: 0;',
                    'overflow: hidden;',
                    'display: flex;',
                    'justify-content: center;',
                    'background:', frogsBackdrop.getBackdropData(traits.backdrop), ';',
                '}',
                '</style>',
                '<rect width="90" height="90" fill="', frogsBackdrop.getBackdropData(traits.backdrop), '"/>',
                _getSVGTraitData(frogsBody.getBodyData(traits.body)),
                _getSVGTraitData(frogsHats.getHatsData(traits.hat)),
                _getSVGTraitData(traits.eyesIsA ? frogsEyesA.getEyesAData(traits.eyesIndex) : frogsEyesB.getEyesBData(traits.eyesIndex)),
                _getSVGTraitData(frogsMouth.getMouthData(traits.mouth)),
                _getSVGTraitData(frogsFeet.getFeetData(traits.feet)),
                '</svg>'
            )
        );
    }

    /**
     * @notice Trims trailing zero bytes from data.
     */
    function trimTrailingZeros(bytes memory data) internal pure returns (bytes memory) {
        uint256 len = data.length;
        while (len > 0 && data[len - 1] == 0) {
            len--;
        }
        bytes memory trimmed = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            trimmed[i] = data[i];
        }
        return trimmed;
    }

    /**
     * @notice Converts bytes data to a string after trimming trailing zeros.
     */
    function _getSVGTraitData(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";
        bytes memory trimmedData = trimTrailingZeros(data);
        return string(trimmedData);
    }

    /**
     * @notice Builds the JSON attributes string for a token.
     */
    function _getFrogTraits(uint tokenId) internal view returns (string memory) {
        TraitStruct memory traits = tokenTraits[tokenId];

        if (traits.oneOfOne) {
            string memory traitName = frogsOneOfOne.getOneOfOneTrait(traits.oneOfOneIndex);
            return string(
                abi.encodePacked(
                    '{"trait_type":"Backdrop", "value":"', frogsBackdrop.getBackdropTrait(traits.backdrop), '"},',
                    '{"trait_type":"Hat", "value":"', traitName, '"},',
                    '{"trait_type":"Eyes", "value":"', traitName, '"},',
                    '{"trait_type":"Mouth", "value":"', traitName, '"},',
                    '{"trait_type":"Body", "value":"', traitName, '"},',
                    '{"trait_type":"Feet", "value":"', traitName, '"}'
                )
            );
        }

        string memory eyesTrait = traits.eyesIsA
            ? frogsEyesA.getEyesATrait(traits.eyesIndex)
            : frogsEyesB.getEyesBTrait(traits.eyesIndex);
        return string(
            abi.encodePacked(
                '{"trait_type":"Backdrop", "value":"', frogsBackdrop.getBackdropTrait(traits.backdrop), '"},',
                '{"trait_type":"Hat", "value":"', frogsHats.getHatsTrait(traits.hat), '"},',
                '{"trait_type":"Eyes", "value":"', eyesTrait, '"},',
                '{"trait_type":"Mouth", "value":"', frogsMouth.getMouthTrait(traits.mouth), '"},',
                '{"trait_type":"Body", "value":"', frogsBody.getBodyTrait(traits.body), '"},',
                '{"trait_type":"Feet", "value":"', frogsFeet.getFeetTrait(traits.feet), '"}'
            )
        );
    }

    // -----------------------------------------------------------------------
    // Admin & Emergency Functions
    // -----------------------------------------------------------------------
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency admin function to manually mark tokens as migrated.
     */
    function markAsMigrated(uint256[] calldata tokenIds) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length; i++) {
            claimed[tokenIds[i]] = true;
        }
    }

    function adminMigrate(uint256[] calldata tokenIds, address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(!claimed[tokenId], "Token already migrated");
            
            // Retrieve traits from old contract
            (
                bool oneOfOne,
                uint oneOfOneIndex,
                uint backdrop,
                uint hat,
                uint eyesIndex,
                bool eyesIsA,
                uint mouth,
                uint body,
                uint feet
            ) = oldContract.tokenTraits(tokenId);
            
            tokenTraits[tokenId] = TraitStruct({
                oneOfOne: oneOfOne,
                oneOfOneIndex: oneOfOneIndex,
                backdrop: backdrop,
                hat: hat,
                eyesIndex: eyesIndex,
                eyesIsA: eyesIsA,
                mouth: mouth,
                body: body,
                feet: feet
            });
            
            _safeMint(recipient, tokenId);
            claimed[tokenId] = true;
            totalMigrated++;
            
            emit TokenMigrated(recipient, tokenId, totalMigrated);
        }
    }
}
