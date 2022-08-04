import os
import pytest
import copy

from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract
from utils import Uint256, str_to_felt

# from contracts.contracts import amm_contract_class

# The path to the contract source code.
AMM_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/amm.cairo")
ERC20_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/test/ERC20.cairo")


INITIAL_MINT = Uint256(100 * 10**18)
MINTER = str_to_felt("MINTER")

@pytest.fixture(scope="session")
async def session_starknet() -> Starknet:
    starknet = await Starknet.empty()
    return starknet

@pytest.fixture(scope="session")
async def two_tokens(
    session_starknet : Starknet
) -> tuple[StarknetContract, StarknetContract]:
    asdf = await session_starknet
    token_a = await asdf.deploy(
        source=ERC20_FILE,
        constructor_calldata=[str_to_felt("TokenA"), str_to_felt("TKNA"), 18, MINTER]
    )

    token_b = await asdf.deploy(
        source=ERC20_FILE,
        constructor_calldata=[str_to_felt("TokenB"), str_to_felt("TKNB"), 18, MINTER]
    )

    return (token_a, token_b)


@pytest.fixture(scope="session")
async def mint_tokens(
    two_tokens : tuple[StarknetContract, StarknetContract]
):
    await two_tokens[0].permissionedMint(123, amount=INITIAL_MINT).invoke(caller_address=MINTER)
    await two_tokens[1].permissionedMint(123, amount=INITIAL_MINT).invoke(caller_address=MINTER)


@pytest.fixture
async def starknet(session_starknet: Starknet) -> Starknet:
    return copy.deepcopy(session_starknet)


@pytest.mark.asyncio
async def test_constructor(starknet : Starknet, two_tokens : tuple[StarknetContract, StarknetContract]):
    starknet = await Starknet.empty()
    (token_a, token_b) = await two_tokens

    contract = await starknet.deploy(
        source=AMM_FILE,
        constructor_calldata=[token_a.contract_address, token_b.contract_address]
    )

    res_a = await contract.get_token_a().call()
    assert res_a.result == (token_a.contract_address,)
    res_b = await contract.get_token_b().call()
    assert res_b.result == (token_b.contract_address,)

