from typing import Tuple

INITIAL_ROOT = 0
INITIAL_BLOCK_NUMBER = -1
UPGRADE_DELAY = 0  # Seconds.
DEFAULT_PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481

StarknetInitData = Tuple[int, str, int, Tuple[int, int]]


class Uint256:
    """
    Simple Uint256 helper class to help using Staknet Uint256 struct.
    """

    def __init__(self, num: int):
        if num < 0:
            num += 2**256
        # This class is used for testing. Therefore illegal values are intionally allowed.
        # Should we make this class stricter, we have to un-comment the following line.
        # assert 0 <= num < 2 ** 256, f"Number {num} out of range for Uint256"
        self.value = num

    @property
    def low(self):
        return self.value % 2**128

    @property
    def high(self):
        return self.value // 2**128

    @classmethod
    def from_pair(cls, low: int, high: int) -> "Uint256":
        return cls(high << 128 + low)

    def uint256(self) -> Tuple[int, int]:
        """
        The name is uint256, because when we pass in a Uint256 into a starknet contract function,
        we actually have to pass in a tuple like this.
        """
        return (self.low, self.high)


def add_implementation_and_upgrade(proxy, new_impl, init_data, governor, is_finalizing=False):
    proxy.addImplementation.transact(
        new_impl, init_data, is_finalizing, transact_args={"from": governor}
    )
    return proxy.upgradeTo.transact(
        new_impl, init_data, is_finalizing, transact_args={"from": governor}
    )

def str_to_felt(short_text: str) -> int:
    felt = int.from_bytes(bytes(short_text, encoding="ascii"), "big")
    assert felt < DEFAULT_PRIME, f"{short_text} is too long"
    return felt