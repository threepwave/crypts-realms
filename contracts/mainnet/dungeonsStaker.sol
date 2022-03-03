// SPDX-License-Identifier: CC0-1.0

/// @title Staking/Unstaking interface for Crypts and Caverns

/*****************************************************
0000000                                        0000000
0001100  Crypts and Caverns                    0001100
0001100     9000 generative on-chain dungeons  0001100
0003300                                        0003300
*****************************************************/

pragma solidity ^0.8.0;

import "hardhat/console.sol"; // HACK Remove before shipping

// TODO - Look into Upgradeable
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./IStarknetCore.sol";

interface IDungeons {
    mapping(uint256 => uint256) public seeds;

    function ownerOf(uint256 tokenId) external view returns (address);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

contract DungeonsStaker is ERC721Holder, Ownable, ReentrancyGuard, Pausable {
    /* Broadcast events for subgraph graph and analytics) */
    event Stake(uint256[] tokenIds, address player);
    event Unstake(uint256[] tokenIds, address player);

    IDungeons dungeons; // Reference to our original Crypts and Caverns contract

    // TODO - Check write gas for uint16 array, map of strct w/ uint256 vs. this map
    mapping(uint256 => uint256) epochStaked;
    mapping(uint256 => address) ownership;

    // optimization idea - store numstaked per address vs full map of tokens

    uint256 genesis;
    uint256 epoch;

    // TODO: document what are these for

    // to get the L2 selector, presuming you have the cairo toolchain installed
    // in python do the following:
    //
    // from starkware.starknet.compiler.compile import get_selector_from_name
    // print(get_selector_from_name('function_name_goes_here'))
    // "stake_tokens"
    uint256 constant L2_STAKER_STAKE_TOKENS_SELECTOR =
        694895510477973960895482936931799549789854741908068836910344771545600811522;
    IStarknetCore public starknetCore;
    uint256 public l2Staker;

    modifier isValidL2Address(uint256 l2Address) {
        require(l2Address != 0, "L2_ADDRESS_OUT_OF_RANGE");
        require(
            l2Address < CairoConstants.FIELD_PRIME,
            "L2_ADDRESS_OUT_OF_RANGE"
        );
        _;
    }

    // TODO: better constructor? ownable and such...
    // _starknetCore - address of the StarkNet Core contract on L1
    // _l2Staker - address (as uint256 / felt) of our staker contract on L2
    //             that handles the L1 <-> L2 communication
    constructor(address _starknetCore, uint256 _l2Staker) {
        require(_starknetCore != address(0));
        require(_l2Staker != address(0));

        starknetCore = IStarknetCore(_starknetCore);
        l2Staker = _l2Staker;
    }

    function addressToUint(address value) internal pure returns (uint256) {
        return uint256(uint160(address(value)));
    }

    function splitUint256(uint256 value)
        internal
        pure
        returns (uint256, uint256)
    {
        uint256 low = value & ((1 << 128) - 1);
        uint256 high = value >> 128;
        return (low, high);
    }

    /**
     * @notice Stakes a dungeon in the contract so rewards can be earned
     * @dev Requires an unstaked dungeon.
     * @param tokenIds Array containing ids of dungeons.
     */
    function stake(uint256[] memory tokenIds)
        external
        whenNotPaused
        nonReentrant
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Verify that user owns this dungeon
            require(
                dungeons.ownerOf(tokenIds[i]) == msg.sender,
                "You do not own this Dungeon"
            );

            // Set ownership of token to staker
            ownership[tokenIds[i]] = msg.sender;

            // Set epoch date for this sender so we know how long they've staked for
            epochStaked[tokenIds[i]] = _epochNum();

            // Transfer Dungeon to staking contract
            dungeons.transferFrom(msg.sender, address(this), tokenIds[i]); // We can use transferFrom to save gas because we know our contract is IERC721Receivable
        }

        emit Stake(tokenIds, msg.sender);
    }

    /**
     * @notice Removes a dungeon from staking (and claims any accrued rewards)
     * @dev Requires a staked dungeon.
     * @param tokenIds Array containing ids of dungeons.
     */
    function unstake(uint256[] memory tokenIds)
        external
        whenNotPaused
        nonReentrant
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Verify that user originally staked this dungeon
            require(
                ownership[tokenIds[i]] == msg.sender,
                "You do not own this Dungeon"
            );

            // Set ownership of token to null (unstaked)
            ownership[tokenIds[i]] = address(0);

            // Reset epoch to zero for this token (unstaked)
            epochStaked[tokenIds[i]] = 0;

            // Transfer dungeon from staking contract back to user
            dungeons.safeTransferFrom(address(this), msg.sender, tokenIds[i]); // We use safeTransferFrom here to make sure the user's wallet is ERC721 compatible
        }

        emit Unstake(tokenIds, msg.sender);
    }

    // TODO: comments
    function bridgeToStarknet(uint256[] memory tokenIds, uint256 l2Recipient)
        external
        whenNotPaused
        isValidL2Address(l2Recipient)
    {
        // build the payload that will be sent via L1->L2 messaging and eventually passed
        // to the @l1_handler function in the Cairo contract
        // the arguments with which the handler will be invoked are:
        //
        //   * address of the L1 owner of the tokens (as uint or felt in Cairo)
        //   * the L2 address of the owner; only this address will be able to
        //     claim the tokens in the L2 contract
        //   * the length of the array of token IDs (a Cairo specific thing)
        //   * the array of token IDs itself
        //   * the length of the array of seeds, which is twice the lenght of
        //     token IDs, because a uint256 has to be split into two values
        //     so it can be made into a Uint256 in Cairo
        //   * the seeds themselves, as 2-tuples (low, high), i.e. each seed
        //     takes up two element in the array
        //
        uint256[] memory payload = new uint256[](4 + tokenIds.length * 3);
        payload[0] = addressToUint(msg.sender);
        payload[1] = l2Recipient;
        payload[2] = tokenIds.length;
        // the length of the seeds 2-tuples, placed after the last tokenId
        payload[tokenIds.length + 3] = tokenIds.length * 2;

        // TODO: test this

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // ensure that the bridged token belongs to the right person
            require(
                ownership[tokenIds[i]] == msg.sender,
                "You did not stake this Dungeon"
            );

            // store the token ID in the payload array
            payload[3 + i] = tokenIds[i];

            // store the seed value, split into a 2-tuple, in
            // the correct position in the payload array
            (low, high) = splitUint256(dungeons.seeds.get(i));
            payload[3 + tokensIds.length + (i * 2)] = low;
            payload[3 + tokensIds.length + (i * 2) + 1] = high;
        }

        // send message to our L2 contract, making the tokens
        // claimable in Starknet
        starknetCore.sendMessageToL2(
            l2Staker,
            L2_STAKER_STAKE_TOKENS_SELECTOR,
            payload
        );

        // TODO: emit event

        // TODO: should we store the fact that these tokenIds have been (and are currently)
        //       bridged to L2? sth like mapping(uint256 => bool) isTokenOnStarknet? what if the
        //       corresponding L2 handler fails (it shouldn't in the current implementation,
        //       but what if we introduce a bug in some future refactor?)
    }

    // TODO: function initiateL2Withdrawal - send a message to L2 to destake tokens
    //       function checkL2WithdrawalStatus - verifies the withdrawal status (can be: none | confirmed | failed - should be sufficient)

    /**
     * @notice Check how many dungeons are currently staked by this user
     * @dev requires a player's address
     */
    function getNumStaked(address _player) public view returns (uint256) {
        uint256 totalDungeons = 0;

        // Loop through mapping (doable because there are only 9000) and count how many the player owns
        for (uint256 i = 1; i <= 9000; i++) {
            if (ownership[i] == _player) {
                totalDungeons++;
            }
        }

        return totalDungeons;
    }

    /**
     * @notice Check which dungeons are staked by a given player
     * @dev requires a player's address
     */
    function getStakedIds(address _player)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory dungeonIds = new uint256[](getNumStaked(_player));

        uint256 count = 0; // Track current array index since we can't use dynamic arrays outside of storage

        // Loop through mapping (doable because there are only 9000) and identify ids the player owns
        for (uint256 i = 1; i <= 9000; i++) {
            if (ownership[i] == _player) {
                dungeonIds[count] = i;
                count++;
            }
        }

        return dungeonIds;
    }

    /**
     * @notice Check the current epoch for calculating how long a dungeon has been staked
     */
    function _epochNum() internal view returns (uint256) {
        return (block.timestamp - genesis) / (epoch * 3600);
    }

    constructor(uint256 _epoch, address _dungeonsAddress) {
        genesis = block.timestamp;
        epoch = _epoch;
        dungeons = Dungeons(_dungeonsAddress);
    }
}
