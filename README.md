# Vesting

Generic Solidity vesting vaults for ERC20 tokens.

## Contracts
### VestingVault
Abstract vesting vault contract that handles general setup and claiming of vested ERC20 tokens. Actual vesting strategies are implemented by inheritor contracts.

### LinearVestingVault
Simple strategy that vests tokens linear over time between a start date and end date.

### ChunkedVestingVault
Strategy allowing for arbitrary vesting periods where funds are released in "chunks" at certain points in time.

# Disclaimer
This is UNAUDITED, EXPERIMENTAL code! Do not use in production.
