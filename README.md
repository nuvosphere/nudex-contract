# nudex-contract

Smart contracts used by nuDex deposits and withdraw

## Deployed Contracts

> Goat Testnet

| Contract           | Address                                    |
| ------------------ | ------------------------------------------ |
| NuvoToken          | 0x9221A8793B9B1333D1FA0a37210652eb5579c677 |
| EntryPoint         | 0x41b26163f1670129b3F5A35C8672c7A87c253467 |
| NuvoLock           | 0x05b0cc53156d66A63eD9870AD6609ac85dF04408 |
| TaskManager        | 0xda8940A59A2cf02957Fed2d5FbcFC13C9c8d5068 |
| ParticipantHandler | 0x0D667283D7fe928611DE49e813546037b44eaC34 |
| AccountHandler     | 0x86a77bdFcAFF7435e1f1DF06A95304D35B112bA8 |
| AssetManager       | 0x35804c8de17Ff6eA7A2681c81935e227fF2133e2 |
| FundsHandler       | 0x5e05e3ef9A37c4D51a76b7CFa1c2546D02912Eaa |

Submitter 0x5623136461EECE9a0A6BC084084b1D1F373AC04f
Tracker 0xA1D927e9B6f7FED90a2763F66eE78FbFBa710Fc7
Participant task submitter 0xA1D927e9B6f7FED90a2763F66eE78FbFBa710Fc7
participant 0 address: 0x331B67539cF7eD49E39F743Ae74e2D152111F7E9
participant 1 address: 0xA80DEAdd39f82981b194AB0e4BFB30190C36dA80
participant 2 address: 0xB6d1f0d7a80b76d03810e3814f3B5a17Aaa3a83c

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
