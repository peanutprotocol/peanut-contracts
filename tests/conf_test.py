import pytest
from brownie import AuthoredEscrow, accounts, config, network


# reset the chain at the beginning of tests
# TODO: not sure this works
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass
