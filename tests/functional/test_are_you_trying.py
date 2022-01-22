from brownie import *
from helpers.constants import MaxUint256


def test_are_you_trying(deployer, vault, strategy, want, governance, gbtc):
    """
    Verifies that you set up the Strategy properly
    """
    # Setup
    startingBalance = want.balanceOf(deployer)

    depositAmount = startingBalance // 2
    assert startingBalance >= depositAmount
    assert startingBalance >= 0
    # End Setup

    # Deposit
    assert want.balanceOf(vault) == 0

    want.approve(vault, MaxUint256, {"from": deployer})
    vault.deposit(depositAmount, {"from": deployer})

    available = vault.available()
    assert available > 0

    vault.earn({"from": governance})

    chain.sleep(10000 * 13)  # Mine so we get some interest

    ## TEST 1: Does the want get used in any way?
    assert want.balanceOf(vault) == depositAmount - available

    # Did the strategy do something with the asset?
    assert want.balanceOf(strategy) < available

    # Use this if it should invest all
    # assert want.balanceOf(strategy) == 0

    wantBefore = want.balanceOf(strategy) 


    # Change to this if the strat is supposed to hodl and do nothing
    # assert strategy.balanceOf(want) = depositAmount

    ## TEST 2: Is the Harvest profitable?
    vaultBalanceBefore = gbtc.balanceOf(strategy)
    harvest = strategy.harvest({"from": governance})
    vaultBalanceAfter = gbtc.balanceOf(strategy) - vaultBalanceBefore
    assert vaultBalanceAfter > 0

    wantAfter = want.balanceOf(strategy) 


    assert wantAfter > wantBefore

    # event = harvest.events["Harvested"]
    # If it doesn't print, we don't want it
    # assert event["amount"] > 0

    ## TEST 3: Does the strategy emit anything?
    #event = harvest.events["TreeDistribution"]
    # assert event["token"] == "TOKEN" ## Add token you emit
    # assert event["amount"] > 0 ## We want it to emit something