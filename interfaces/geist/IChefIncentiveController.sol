pragma solidity 0.6.12;

interface IChefIncentiveController {
    
    // Claim pending rewards for one or more pools.
    // Rewards are not received directly, they are minted by the rewardMinter.
    function claim(address _user, address[] calldata _tokens) external 

}