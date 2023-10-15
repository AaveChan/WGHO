## Wrapped GHO implementation

Design decisions for the review:

- Rescuable
- Function unrolling
- If you send wGHO to the wGHO contract you receive your GHO and the wGHO get burned
- Permit

Run tests with:

forge test --fork-url mainnet-rpc