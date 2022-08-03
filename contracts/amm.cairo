%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_nn, assert_not_zero
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_le, uint256_eq, uint256_mul, uint256_unsigned_div_rem
from contracts.interfaces.IERC20 import IERC20

struct Position:
    member id : felt
    member a_balance : Uint256
    member b_balance : Uint256
end

#
# STORAGE VARIABLES
#

@storage_var
func token_a() -> (token_a : felt):
end

@storage_var
func token_b() -> (token_b : felt):
end

@storage_var
func reserves() -> (reserves : (Uint256, Uint256)):
end

@storage_var
func positions(user : felt) -> (position : Position):
end

#
# GETTERS
#

@view
func get_token_a{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (token_a : felt):
    let (a) = token_a.read()
    return (token_a=a)
end

@view
func get_token_b{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (token_b : felt):
    let (b) = token_b.read()
    return (token_b=b)
end

@view
func get_reserve_a{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (reserve_a : Uint256):
    let (rsrs) = reserves.read()
    return (reserve_a=rsrs[0])
end

@view
func get_reserve_b{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (reserve_b : Uint256):
    let (rsrs) = reserves.read()
    return (reserve_b=rsrs[1])
end

@view
func get_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user : felt
) -> (position : Position):
    let (position) = positions.read(user=user)
    return(position)
end


#
# CONSTRUCTOR
#

@constructor
func constructor{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(a : felt, b : felt):
    token_a.write(value=a)
    token_b.write(value=b)
    return ()
end

#
# EXTERNAL FUNCTIONS
#

@external
func deposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(a_amount : Uint256, b_amount : Uint256):
    alloc_locals
    let (caller_address) = get_caller_address()
    let (contract_address) = get_contract_address()
    let (rsrs) = reserves.read()

    let (position) = positions.read(caller_address)
    let (new_balance_a, _) = uint256_add(position.a_balance, a_amount)
    let (new_balance_b, _) = uint256_add(position.b_balance, b_amount)

    # update position
    let new_position = Position(
        caller_address,
        a_balance=new_balance_a,
        b_balance=new_balance_b,
    )
    positions.write(caller_address, new_position)

    # update reserves
    let (new_a, _) = uint256_add(rsrs[0], a_amount)
    let (new_b, _) = uint256_add(rsrs[1], b_amount)
    reserves.write((new_a, new_b))

    # transfer tokens in
    let (a) = token_a.read()
    let (b) = token_b.read()
    IERC20.transferFrom(contract_address=a, sender=caller_address, recipient=contract_address, amount=a_amount)
    IERC20.transferFrom(contract_address=b, sender=caller_address, recipient=contract_address, amount=b_amount)

    return()
end

@external
func withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    a_amount : Uint256,
    b_amount : Uint256
):
    alloc_locals
    let (caller_address) = get_caller_address()
    let (local position) = positions.read(caller_address)
    let (rsrs) = reserves.read()

    # verify withdraw amounts are valid
    let (withdraw_limit_a) = uint256_le(a_amount, position.a_balance)
    let (withdraw_limit_b) = uint256_le(b_amount, position.b_balance)
    assert withdraw_limit_a + withdraw_limit_b = 2
    
    let (new_position_balance_a) = uint256_sub(position.a_balance, a_amount)
    let (new_position_balance_b) = uint256_sub(position.b_balance, b_amount)

    # update position
    let new_position = Position(
        caller_address,
        a_balance=new_position_balance_a,
        b_balance=new_position_balance_b,
    )
    positions.write(caller_address, new_position)

    # update reserves
    let (new_a) = uint256_sub(rsrs[0], a_amount)
    let (new_b) = uint256_sub(rsrs[0], b_amount)
    reserves.write((new_a, new_b))

    # transfer tokens
    let (a) = token_a.read()
    let (b) = token_b.read()
    IERC20.transfer(contract_address=a, recipient=caller_address, amount=a_amount)
    IERC20.transfer(contract_address=b, recipient=caller_address, amount=b_amount)

    return()
end

@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount_out : Uint256, a_in : felt
):
    alloc_locals
    let (caller_address) = get_caller_address()
    let (contract_address) = get_contract_address()
    let (rsrs) = reserves.read() 
    let (a : felt) = token_a.read()
    let (b : felt) = token_b.read()

    # set correct variables
    local token_transfer_out : felt
    local token_transfer_in : felt
    local old_in_balance : Uint256

    if a_in == 1:
        assert token_transfer_out = b
        assert token_transfer_in = a
        assert old_in_balance = rsrs[0]
    else:
        assert token_transfer_out = a
        assert token_transfer_in = b
        assert old_in_balance = rsrs[1]
    end

    # transfer out the correct token
    IERC20.transfer(contract_address=token_transfer_out, recipient=caller_address, amount=amount_out)
    let (new_out_balance) = IERC20.balanceOf(contract_address=token_transfer_out, account=contract_address)

    # calculate amount in
    let (k, _) = uint256_mul(rsrs[0], rsrs[1])
    let (amount_in_minus_old, _) = uint256_unsigned_div_rem(k, new_out_balance)
    let (amount_in, _) = uint256_add(amount_in_minus_old, old_in_balance)

    # transfer in
    IERC20.transferFrom(contract_address=token_transfer_in, sender=caller_address, recipient=contract_address, amount=amount_in)

    # update reserves
    if a_in == 1:
        let (new_a, _) = uint256_add(rsrs[0], amount_in)
        let (new_b) = uint256_sub(rsrs[1], amount_out)
        reserves.write((new_a, new_b))
    else:
        let (new_a) = uint256_sub(rsrs[0], amount_out)
        let (new_b, _) = uint256_add(rsrs[1], amount_in)
        reserves.write((new_a, new_b))
    end
    
    return()
end
