# Orcfax Latest Price Smart Contract: Product Specification

## Goal

Provide DeFi protocols on Cardano with a single, canonical UTxO per price feed that should contain the latest validated price derived from Orcfax Fact Statements (FS), optionally composed from multiple feeds, for example, a CNT-USD feed derived from CNT-ADA and ADA-USD.

This contract is read-only for consumers (they use the datum as a reference input) and permissioned for updaters (just a selected PubKeyHash, the bot, can sign a transaction that proves a newer Orcfax statement). This enables a sanity check in the off-chain logic of the bot, i.e., in case of discrepancy with other price sources, the bot decides not to update the price feed on-chain until the fact statements publish accurate data.

## Scope

* A Plutus/Aiken smart contract that:  
  * Manages a “latest price” UTxO keyed by a LatestPrice NFT.  
  * Validates Orcfax FS and enforces “newer-than-previous” updates.  
  * Supports single- and multi-feed price composition.  
  * Enables an optional change of permissions  
* Composable Feeds Configs  
  * Single Feed \- Just ADA/USD  
  * Direct Derived Feed \- ADA/USD / BTC/USD \= ADA / BTC \= 0.0000472  
  * Inverted Derived Feed \- 1 / (ADA/USD / BTC/USD ) \= BTC / ADA \= 165200.0000  
    * OnChainDecimal \= 165\_200\_000\_000  
* Configuration per feed instance:  
  * One-shot currency that generates the LatestPrice NFT and an AuxiliaryDatum NFT  
  * List of allowed Orcfax feed\_id prefixes.  
  * Expression / function encoding how to combine feeds (e.g. ADA/BTC \= ADA/USD ÷ BTC/USD).  
  * An time\_to\_live value in milliseconds.  
* On-chain sanity checks, e.g.:  
  * Non-negative price.  
  * Non-zero denominator when converting from rational.  
* Off-chain SDK & bot  
  * A lucid-evolution/evolution SDK that allows users to interact with the latest price contract.  
    * Endpoints such as: UpdateFeed, UpdatePermissions  
  * A typescript bot that parses the chain (including the mem-pool) to get the latest feeds from the Orcfax publisher, and when appropriate updates the Latest Price feed state.

## Requirements

**Parameters**  
This is the datum that will be consumed by the contracts reading the price:

`LatestPriceParameters {`  
	`composed_feeds:`   
`}`

**Datums**  
This is the datum that will be consumed by the contracts reading the price:  
`OnChainDecimal {`  
     `get_on_chain_int: 1_500_000 // = 1.500000`  
`}`

`LatestPriceDatum {`  
	`price: OnChainDecimal,`  
	`expiration: Int`  
`}`

These are auxiliary data that can’t be added to the main UTXO because the existing contracts wouldn’t be able to parse the datum but these auxiliary are necessary:

`AuxiliaryDatum {`  
	`last_created_at: List<(ByteArray, Int)>,`  
	`feed_ctrl_pkh: PubKeyHash,`  
	`admin_permissions: MultisigScript,`  
`}`

The MultisigScript type is from the aiken package [https://github.com/SundaeSwap-finance/aicone](https://github.com/SundaeSwap-finance/aicone).

**Initialization**

The initialization of the latest price feed will do a few things:

1. A smart contract will be parameterized with the following details:  
   1. The composition of feeds and functions to be able to derive the price.  
   2. An integer value for expiration bias  
2. The LatestPrice NFT authenticating the LatestPriceDatum UTXO will be minted using the “Mint” purpose of the smart contract.  
   1. This NFT will be sent to the smart contract script hash where  
      1. The price will be 0   
      2. The expiration will be 0  
   2. It must be ensured that exactly one NFT exists.  
3. The Auxiliary NFT authenticating the AuxiliaryDatum UTXO will be minted using the “Mint” purpose of the smart contract.  
   1. This NFT will be sent to the smart contract script hash where:  
      1. last\_created\_at will be 0  
      2. latest\_price\_utxo\_nft will be the LatestPrice NFT  
      3. The feed\_ctrl\_pkh will be the bot’s pub key hash  
      4. The admin\_permissions will be set appropriately  
4. A reference script will be published to an always-fail script with an active staking credential.

**Update Feed**

The action for updating the price of a feed.

Constraints:

1. The transaction is signed by feed\_ctrl\_pkh  
2. Spending single LatestPriceDatum UTXO  
3. Spending single AuxiliaryDatum UTXO that which latest\_price\_utxo\_nft is the same as the NFT of the LatestPriceDatum UTXO  
4. All composed feeds are referenced.  
   1. We must cross-reference the last\_created\_at we have stored in the AuxiliaryDatum UTxO with the created\_at of Fact Statement we are referencing.  
      1. There must be at least one fact statement that is newer than the one we have stored.  
      2. None can be older than the last\_created\_at’s we have stored.  
5. The newly produced LatestPriceDatum UTXO has:   
   1. correctly calculated price based on the referenced fact statements.  
   2. correctly set expiration based on the new created\_at of a fact statement (expiration \= created\_at \+ parameters.expiration\_bias)  
6. The newly produced AuxiliaryDatum UTXO has last\_created\_at updated to the created\_at of the fact statement. Other fields are unchanged.

**UpdatePermissions**

The purpose of this action is the option for permissions rotation. E.g., once every 3 months, change the permissions for signing the update feed transaction.

Constraints:

1. Single AuxiliaryDatum UTXO is spent  
2. Tx satisfies the admin\_permissions  
3. The newly produced AuxiliaryDatum UTXO can have changed only the fields admin\_permissions and feed\_ctrl\_pkh

## Open Sourcing

This project will be released as an open-source contract under the MIT license.

## Deployment & Operations

Each feed will have its own independent bot to track the Fact Statement Feeds and publish updates to the chain as quickly as possible. This bot will need to be auditable in terms of which fact statements it is using to derive the prices it publishes.

## Other Considerations

* The lower the cost of publishing the latest price feed, the better. We need to be really thoughtful about tx fees for this project.  
* Composition of derived price: We need to discuss how we will allow the composition of the price feed derivation in the smart contract parameters.  
* Possibly let’s allow the script to be spent to a parameterized staking credential.  
* Optional Admin Key: There is this project (sundae/aicone) which allows for pretty comprehensive multi-sig features. [https://github.com/SundaeSwap-finance/aicone](https://github.com/SundaeSwap-finance/aicone)	
