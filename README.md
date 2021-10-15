# cryptodemonz-nft-staking

**Full readme later**

![graph](https://cdn.discordapp.com/attachments/883492061469368322/883642383038840852/Screenshot_2021-09-04_11-18-56.png)


def formula(rarity, normalizer, daysStaked, multi, amountOfStakers):
    baseM = multi * daysStaked
    baseR = normalizer * rarity
    baseMR = baseM * baseR
    final = baseMR // amountOfStakers

    return final

# CryptoDemonz v1 case, multiplier is 2, staking period is 30 days and we have 300 people staking in pool
print("Rarity rank #1", formula(570.05, 1, 30, 2, 300)) # makes 114 LLTH in a month
print("Rarity rank #9992", formula(45.10, 1, 30, 2, 300)) # makes 9 LLTH in a month

# MightyBabyDragons case
# Before normalizer, highest rarity score is: 1056.36
# After normalizing it by multiplying on 0.5: 528 (Demonzv1 highest rarity: 570)
# Same example, multiplier is 2, staking period is 30 days and we have 300 people staking in pool
print("Rarity rank #1", formula(1056.36, 0.5, 30, 2, 300)) # makes 105 LLTH in a month
print("Rarity rank #9992", formula(55.55, 0.5, 30, 2, 300)) # makes 5 LLTH in a month