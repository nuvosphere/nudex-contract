# nudex-contract

Smart contracts used by nuDex deposits and withdraw

## Deployed Contracts

> Goat Testnet

| Contract           | Address                                    |
| ------------------ | ------------------------------------------ |
| NuvoToken          | 0xb1de22C4DAAcB986d8bD39Fb0FCC9D54C511002E |
| EntryPoint         | 0x41fE471e8A62b62D12582b9068a8c848eba5C833 |
| NuvoLock           | 0x90D9e5b8B644e4BEEc3C60f59F4dF3116108c4Ed |
| TaskManager        | 0x4F8d9fB22c404A34502aD9fe6f7667055485FF41 |
| ParticipantHandler | 0x77acDbaFb570F66a2C73d9d20403e1a24B311649 |
| AccountHandler     | 0x63D1722Bc288d72277274C8B1B1379Db3Af3FbcC |
| AssetHandler       | 0x67307896F71CCa4ed6B24927c833589eDdD6d392 |
| FundsHandler       | 0x585A0eE04a42258D57ABC939238c54A78412c46C |

submitter: 0x1D2cd50A3cF3c55a7982AD54F9f364C1e953Bc57  
participant 0 address: 0x3a818294ca1F3C27d7588b123Ec43F2546fa07f4  
participant 1 address: 0x04d9389Cf937b1e6F2258d842e7237E955d6ab04  
participant 2 address: 0xf6D37CE75dB465DcDb4c7097bEB9c1D46b171037

> Goat Testnet (test environment)

| Contract           | Address                                    |
| ------------------ | ------------------------------------------ |
| NuvoToken          | 0xE4D4d103C5E4BA35FA75Cd8c1CB1576b813c1dE4 |
| EntryPoint         | 0x6AB289CDb97ED7B72FC737e7C7A38458930BcD58 |
| NuvoLock           | 0x6CD32e4dE8e16665c4B50DfD56071A6A97961963 |
| TaskManager        | 0xB79D976d993591cC0bAcB7D0C50E118a3d78f21b |
| ParticipantHandler | 0x4051EF5d9c78F335C2F6666BF692C130db6810cf |
| AccountHandler     | 0x74F6037090Af84679631349b662B7898AdA35442 |
| AssetManager       | 0x6E2ab301D2A180eE256f0873cb88CbB6e3d7CaD2 |
| FundsHandler       | 0x1795C5Bbe34B11F108280FAF63CAD12526666193 |

## Workflow

1. Task Submission via Handler Contracts

Tasks are initially submitted through `Handler` contracts, each of which has a whitelisted set of submitter addresses. The Handler contract provides two main functions for managing tasks:

- **submit()**: This function is called by a whitelisted submitter address to submit a new task.
- **record()**: This function finalizes and records the task after it has been verified and executed.

The submitted tasks are stored in the TaskManager as the following struct:

```solidity
struct Task {
    State state;        // Current state of the task (Created, Pending, Completed, Failed)
    address handler;    // Address of the handler contract
    bytes32 dataHash;   // The hashed callData for verification during execution
}
```

2. Off-Chain Verification by `TSS (Threshold Signature Scheme)`

Once a task is submitted, the content (callData) will be verified by the TSS system off-chain. The TSS participants must validate the task details to ensure the task is legitimate before any action is taken on-chain.

3. Task Execution by TSS Participants

After off-chain verification, a randomly selected TSS participant will execute the task by interacting with the `EntryPoint` contract:

- 3.1 Calling the VerifyAndCall() Function

  A randomly selected TSS participant will call the `VerifyAndCall()` function on the `EntryPoint` contract. This function initiates the task execution process.

- 3.2 `Signature` and `DataHash` Verification

  - The TSS participant’s signature will be verified to confirm their authorization to execute the task.
  - The dataHash of the task (which was submitted in step 1) will be compared with the hash of the callData to ensure they match, ensuring that the correct task is being executed.

- 3.3 Handler Record Function Execution

  Once all checks are passed, the EntryPoint contract will call the corresponding `Handler` using the callData to complete the task.

4. Random Selection of TSS Participants

After each task execution, the TSS participant will receive a bonus point for successfully executing the task. A new TSS participant will be randomly selected from the participant pool to execute subsequent tasks.
