# the L2 bridge / gateway for the tokens to Starknet

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.messages import send_message_to_l1

struct DungeonClaim:
    member l1_owner_addr : felt  # address of the owner of the dungeon on L1 (the address that initiated the L1 -> L2 bridging)
    member l2_recipient_addr : felt  # Starknet address which can claim (mint) the token on L2
    member token_id : felt  # token ID of the dungeon
    member seed : Uint256  # the seed value for the Dungeon's attributes (name, size, environmenet)
end

# the address of the staking / bridging contract on L1
@storage_var
func l1_staker_addr() -> (addr : felt):
end

# mapping of token IDs that are available for claiming, i.e.
# they have been staked in L1 and successfully bridged to L2
# if a token ID is in this storage var, a user can call
# claim and the Dungeon will get minted as an NFT on Starknet
@storage_var
func claimable(token_id : felt) -> (claim : DungeonClaim):
end

# mapping of token IDs that have been minted and are currently
# "active" on L2; when a token gets removed from Starknet, the
# Dungeon NFT is burned and the value of the token ID herein is 0
@storage_var
func minted(token_id : felt) -> (yesno : felt):
end

# what to pass in the args?
# * l1_staker addr
# * Dungeon.cairo (NFT contract) addr
# * owner addr
#
# how do we want to build the contract WRT initialize, ownable, upgradability, etc.?
# @constructor
# func constructor() -> ():
#     return ()
# end

@l1_handler
func stake_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        from_address : felt, l1_owner_addr : felt, l2_recipient_addr : felt, token_ids_len : felt,
        token_ids : felt*, seeds_len : felt, seeds : felt*):
    alloc_locals

    let (l1_staker_addr_) = l1_staker_addr.read()
    with_attr error_message("incorrect L1 sender"):
        assert from_address = l1_staker_addr_
    end

    # TODO: should we assert token_ids_len * 2 == seeds_len?
    #       or some other relationship between them? isn't a thorough test of the L1 contract enough?

    make_tokens_claimable(
        l1_owner_addr, l2_recipient_addr, token_ids_len, token_ids, seeds_len, seeds)

    # tokens have been saved, ready for claiming

    # TODO: emit event

    return ()
end

@l1_handler
func process_withdrawal_request{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        from_address : felt, l1_owner_addr : felt, token_ids_len : felt, token_ids : felt*):
    alloc_locals

    let (l1_staker_addr_) = l1_staker_addr.read()
    with_attr error_message("incorrect L1 sender"):
        assert from_address = l1_staker_addr_
    end

    let (did_succeed) = unstake_tokens(token_ids_len, token_ids)

    # TODO: emit event

    if did_succeed == 0:
        # failure
        # build payload to send to L1, first entry should be message_type
        # TODO: make it a const, sth like PROCESS_WITHDRAWAL_RESPONSE
        #       and have the same in the .sol contract as well
        let (payload) = alloc()
        assert payload[0] = 1  # PROCESS_WITHDRAWAL_RESPONSE
        assert payload[1] = 0  # failure
        send_message_to_l1(from_address, 2, payload)
    else:
        # TODO: see comments in the above branch
        let (payload) = alloc()
        assert payload[0] = 1  # PROCESS_WITHDRAWAL_RESPONSE
        assert payload[1] = 1  # success
        # maybe pass in the token IDs that have been burnt / can be withdrawn?
        send_message_to_l1(from_address, 2, payload)

        # TODO: emit event
    end

    return ()
end

func make_tokens_claimable{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        l1_owner_addr : felt, l2_recipient_addr : felt, token_ids_len : felt, token_ids : felt*,
        seeds_len : felt, seeds : felt*) -> ():
    alloc_locals

    # check if we're done
    if token_ids_len == 0:
        return ()
    end

    # build the Dungeon struct and store it in the claimable map with its token ID as key
    let token_id = [token_ids]
    let seed = Uint256(low=[seeds], high=[seeds + 1])
    let dungeon_claim = DungeonClaim(
        l1_owner_addr=l1_owner_addr,
        l2_recipient_addr=l2_recipient_addr,
        token_id=token_id,
        seed=seed)
    claimable.write(token_id, dungeon_claim)

    # move on to the next token id
    return make_tokens_claimable(
        l1_owner_addr,
        l2_recipient_addr,
        token_ids_len - 1,
        token_ids + 1,
        seeds_len - 2,
        seeds + 2)
end

func unstake_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_ids_len : felt, token_ids : felt*) -> (outcome : felt):
    alloc_locals

    if token_ids_len == 0:
        return (1)  # success
    end

    let token_id = [token_ids]
    let (is_token_minted) = minted.read(token_id)

    if is_token_minted == 0:
        # token is not minted, cannot be unstaked,
        # returning a failure result
        return (0)
    end

    # "delete" token from the mapping of minted ones
    minted.write(token_id, 0)

    # TODO: anything else we need to do?

    return unstake_tokens(token_ids_len - 1, token_ids + 1)
end

# check if a token by ID can be claimed; returns 0 if
# it not (false) or the token ID (true) if it can be claimed
@view
func can_claim{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt) -> (yesno : felt):
    let (dungeon_claim) = claimable.read(token_id)
    return (dungeon_claim.token_id)
end

@external
func claim{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_ids_len : felt, token_ids : felt*) -> ():
    alloc_locals

    if token_ids_len == 0:
        return ()
    end

    let token_id = [token_ids]
    let (dungeon_claim) = claimable.read(token_id)

    with_attr error_message("token not claimable"):
        assert_not_zero(dungeon_claim.token_id)
    end

    with_attr error_message("owner mismatch"):
        let (caller_addr) = get_caller_address()
        assert dungeon_claim.l2_recipient_addr = caller_addr
    end

    # TODO: mint a fresh Dungeon for the owner

    # zero-out the token ID from the claimable mapping
    claimable.write(
        token_id,
        DungeonClaim(l1_owner_addr=0, l2_recipient_addr=0, token_id=0, seed=Uint256(0, 0)))

    # mark the token ID as minted
    minted.write(token_id, 1)

    # moving on to the next token in the list
    return claim(token_ids_len - 1, token_ids + 1)
end

@view
func is_minted{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt) -> (yesno : felt):
    let (is_minted) = minted.read(token_id)
    return (is_minted)
end
