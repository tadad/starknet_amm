import os.path

from starkware.starknet.services.api.contract_class import ContractClass

DIR = os.path.dirname(__file__)

amm_contract_class = ContractClass.loads(
    data=open(os.path.join(DIR, "../abis/amm_compiled.json")).read()
)

erc20_contract_class = ContractClass.loads(
    data=open(os.path.join(DIR, "../abis/erc20_compiled.json")).read()
)
