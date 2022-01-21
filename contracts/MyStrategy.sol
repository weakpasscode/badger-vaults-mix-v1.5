// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {BaseStrategy} from "@badger-finance/BaseStrategy.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {IChefIncentiveController} from "../interfaces/geist/IChefIncentiveController.sol";
import {ILendingPool} from "../interfaces/geist/ILendingPool.sol";

import {IV2SwapRouter} from "../interfaces/uniswap/Router.sol";

contract MyStrategy is BaseStrategy {
    // address public want; // Inherited from BaseStrategy
    // address public lpComponent; // Token that represents ownership in a pool, not always used
    // address public reward; // Token we farm

    address public constant BADGER = 0x3472A5A71965499acd81997a54BBA8D852C6E53d;
    address public constant LENDING_POOL = 0x9FAD24f572045c7869117160A571B2e50b10d068;

    address public constant GEIST_TOKEN = 0xd8321AA83Fb0a4ECd6348D4577431310A6E0814d;
    address public constant ROUTER = 0xF491e7B69E4244ad4002BC14e878a34207E38c29; //spookyswap router

    // geist token 0xd8321aa83fb0a4ecd6348d4577431310a6e0814d

    //gbtc 0x38aca5484b8603373acc6961ecd57a6a594510a3
    // wbtc 0x321162Cd933E2Be498Cd2267a90534A804051b11
    // spooky router 0xf491e7b69e4244ad4002bc14e878a34207e38c29

    address public constant INCENTIVES_CONTROLLER = 0x297FddC5c33Ef988dd03bd13e162aE084ea1fE57;

    address public gBTC; // Token we provide liquidity with
    address public reward; // Token we farm and swap to want / aToken

    /// @dev Initialize the Strategy with security settings as well as tokens
    /// @notice Proxies will set any non constant variable you declare as default value
    /// @dev add any extra changeable variable at end of initializer as shown
    function initialize(address _vault, address[3] memory _wantConfig) public initializer {
        __BaseStrategy_init(_vault);
        /// @dev Add config here
        want = _wantConfig[0];
        gBTC = _wantConfig[1];
        reward = _wantConfig[2];

        // If you need to seit new values that are not constants, set them like so
        // stakingContract = 0x79ba8b76F61Db3e7D994f7E384ba8f7870A043b7;

        // If you need to do one-off approvals do them here like so
        IERC20Upgradeable(want).safeApprove(LENDING_POOL, type(uint256).max);
        IERC20Upgradeable(gBTC).safeApprove(LENDING_POOL, type(uint256).max);

        /// @dev Allowance for Uniswap
        IERC20Upgradeable(reward).safeApprove(ROUTER, type(uint256).max);
        IERC20Upgradeable(GEIST_TOKEN).safeApprove(ROUTER, type(uint256).max);
    }

    /// @dev Return the name of the strategy
    function getName() external pure override returns (string memory) {
        return "wbtc-geist";
    }

    /// @dev Return a list of protected tokens
    /// @notice It's very important all tokens that are meant to be in the strategy to be marked as protected
    /// @notice this provides security guarantees to the depositors they can't be sweeped away
    function getProtectedTokens() public view virtual override returns (address[] memory) {
        address[] memory protectedTokens = new address[](2);
        protectedTokens[0] = want;
        protectedTokens[1] = BADGER;
        return protectedTokens;
    }

    /// @dev Deposit `_amount` of want, investing it to earn yield
    function _deposit(uint256 _amount) internal override {
        // No-op as we don't do anything
        ILendingPool(LENDING_POOL).deposit(want, _amount, address(this), 0);
    }

    /// @dev Withdraw all funds, this is used for migrations, most of the time for emergency reasons
    function _withdrawAll() internal override {
        ILendingPool(LENDING_POOL).withdraw(want, balanceOfPool(), address(this));
    }

    /// @dev Withdraw `_amount` of want, so that it can be sent to the vault / depositor
    /// @notice just unlock the funds and return the amount you could unlock
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        if (_amount > balanceOfPool()) {
            _amount = balanceOfPool();
        }

        ILendingPool(LENDING_POOL).withdraw(want, _amount, address(this));
        return _amount;
    }

    /// @dev Does this function require `tend` to be called?
    function _isTendable() internal pure override returns (bool) {
        return false; // Change to true if the strategy should be tended
    }

    function _harvest() internal override returns (TokenAmount[] memory harvested) {
        uint256 _before = IERC20Upgradeable(want).balanceOf(address(this));

        harvested = new TokenAmount[](2);
        harvested[0] = TokenAmount(want, 0);
        harvested[1] = TokenAmount(BADGER, 0);

        address[] memory tokensToClaim = new address[](1);
        tokensToClaim[0] = GEIST_TOKEN;

        IChefIncentiveController(INCENTIVES_CONTROLLER).claim(address(this), tokensToClaim);

        uint256 rewardsAmount = IERC20Upgradeable(reward).balanceOf(address(this));
        if (rewardsAmount == 0) {
            return harvested;
        }

        // Swap Rewards in Spookyswap

        address[] memory path = new address[](2);
        path[0] = GEIST_TOKEN;
        path[1] = want;

        // TODO: fix max amount chances of FR
        IV2SwapRouter(ROUTER).swapExactTokensForTokens(rewardsAmount, 0, path, address(this));

        uint256 earned = IERC20Upgradeable(want).balanceOf(address(this)).sub(_before);

        // keep this to get paid!
        _reportToVault(earned);

        return harvested;
    }

    // Example tend is a no-op which returns the values, could also just revert
    function _tend() internal override returns (TokenAmount[] memory tended) {
        // Nothing tended
        tended = new TokenAmount[](3);
        tended[0] = TokenAmount(want, 0);
        tended[1] = TokenAmount(BADGER, 0);
        tended[1] = TokenAmount(BADGER, 0);

        return tended;
    }

    /// @dev Return the balance (in want) that the strategy has invested somewhere
    function balanceOfPool() public view override returns (uint256) {
        return IERC20Upgradeable(gBTC).balanceOf(address(this));
    }

    /// @dev Return the balance of rewards that the strategy has accrued
    /// @notice Used for offChain APY and Harvest Health monitoring
    function balanceOfRewards() external view override returns (TokenAmount[] memory rewards) {
        // Rewards are 0
        rewards = new TokenAmount[](2);
        rewards[0] = TokenAmount(want, 0);
        rewards[1] = TokenAmount(BADGER, 0);
        rewards[1] = TokenAmount(gBTC, 0);
        rewards[1] = TokenAmount(reward, 0);
        return rewards;
    }
}
