# Cryptodemonz NFT Staking (Pre-deployment)

## TL;DR

Using a trait distribution based equation that determines the rarity of any NFT from any project, we've designed the first-ever
**non-fungible token yield farming system that evaluates each token OBJECTIVELY, purely based on their traits and reward
investors respectively to their shares in our pools**

Apart from this unique feature, we've also developed a hybrid, multi-chain system to utilize chainlink while reducing fees
needed to make external oracle calls and reducing the overall gas fees as well, paid when collecting rewards. Thus, making
this ecosystem profitable for our users. 

To sum up, any project with limited AND FULLY MINTED supply (preferably between 10k-20k tokens) will be able to request
place in our platform, incentivising their community and possibly developing their own, better contracts based on our code,
which is under **MIT license, thus any commercial or private use MUST comply with certain requirements, such as:
copyright notice**

## Yield Farming

Details about our equation and reward processing can be found in our whitepaper, here we will just go over the basics. 

Rewarding will happen in (x)LLTH (LLTH on ethereum, xLLTH on a polygon, we will explain this below) ERC20 token which can be traded in 
Sushiswap with Ethereum. Calculation of mentioned rewards is based on days, rather than conventional per-block emission. There are no
restrictions on how many tokens will be minted, but restrictions will cover harvest cooldown and various limits in terms of staking. 
This was designed to avoid giving too much "free money" and creating inflation, even though our token has amazing post-utility in Abyss
games.

## Multi-chain system, LLTH and xLLTH

Our staking platform isn't that straightforward as it sounds. It might be for users - just stake and earn yield but in terms of
what's going on behind the curtains. And this is caused by one single problem, which is the way we acquire information about each NFT.
It happens through chainlink oracle that will call our API, this one will feed rarity scores to contract, but before this, our API should
call opensea API to get the trait distribution info FOR EACH NFT. Seems complex, but this isn't the scary part, it's just very VERY expensive. So we had 
to find another, less-expensive solution and that's when we came with a hybrid, multi-chain system. 

The idea is to put the Harvest function on the polygon, where chainlink calls will be very cheap while leaving Stake/Unstake functions on Ethereum,
this will let users collect rewards on a polygon, while their tokens stay on Ethereum. This multi-chain process will be delegated by our React app,
with ownership on Harvest, it can take information from Ethereum and feed it to polygon contract when the user clicks on the Harvest button. For a user,
it's a straightforward process, quite literally just "click on the button".

Since we already have xLLTH (LLTH ethereum) clone on Polygon for our Abyss games, that frankly also has manager ownership, instead of only owner
restriction, we can mint xLLTH to users, then they can either play in Abyss or bridge it to ethereum using our exclusive Bridge and sell it for profits.
