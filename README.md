# nudex-contract

Smart contracts used by nuDex deposits and withdraw

## Deployed Contracts

> Goat Testnet

| Contract           | Address                                    |
| ------------------ | ------------------------------------------ |
| NuvoToken          | 0xb1de22C4DAAcB986d8bD39Fb0FCC9D54C511002E |
| EntryPoint         | 0x409825a8EC85C10f853ed22D0DBA47f0DcA15089 |
| NuvoLock           | 0x37FBCF60EdA311D25954fD0837a86Ba389a4155B |
| TaskManager        | 0x09825E7364bcFd776251467115439328e67E8346 |
| ParticipantHandler | 0x0335bb52282521015FF96FcD15e5DA30001613b2 |
| AccountHandler     | 0x4b70853C7f73b2f1daBb526C9fACC955415a8EEA |
| AssetHandler       | 0x8f5020E514A36ff8e50B15a53c121b5CE59CaAdD |
| FundsHandler       | 0x38D55C9c45C97AD624d47bA03560D3a569146359 |

submitter: 0x1D2cd50A3cF3c55a7982AD54F9f364C1e953Bc57  
participant 0 address: 0x3a818294ca1F3C27d7588b123Ec43F2546fa07f4  
participant 1 address: 0x04d9389Cf937b1e6F2258d842e7237E955d6ab04  
participant 2 address: 0xf6D37CE75dB465DcDb4c7097bEB9c1D46b171037

> Goat Testnet (test environment)

| Contract           | Address                                    |
| ------------------ | ------------------------------------------ |
| NuvoToken          | 0xb1de22C4DAAcB986d8bD39Fb0FCC9D54C511002E |
| EntryPoint         | 0x3d2046BE1D5276bC787Cd09d77A24e6fDf5d8771 |
| NuvoLock           | 0xf224326d073f69F7BF8eEA9DF60D857Fa739ed3A |
| TaskManager        | 0x72c740EF47A3dBF1908CEaE85634c35E3830715e |
| ParticipantHandler | 0x117602D02a9b4aE53D44F4b686A38d1Ed6ACaBE8 |
| AccountHandler     | 0xbAeC596399DA873fD1787751b3E6470E76689d1D |
| AssetHandler       | 0xD4b8dAE4483a38fdd8E44aD16F17f8713b9c2e9c |
| FundsHandler       | 0xb5E3919cbf4B587A29AA0Ff31DeCaAfDC8d56ed5 |

submitter: 0x1D2cd50A3cF3c55a7982AD54F9f364C1e953Bc57  
participant 0 address: 0x3a818294ca1F3C27d7588b123Ec43F2546fa07f4  
participant 1 address: 0x04d9389Cf937b1e6F2258d842e7237E955d6ab04  
participant 2 address: 0xf6D37CE75dB465DcDb4c7097bEB9c1D46b171037

## Workflow

1. Task Submission via Handler Contracts

Tasks are initially submitted through `Handler` contracts, each of which has a whitelisted set of submitter addresses. The Handler contract provides two main functions for managing tasks:

- **submit()**: This function is called by a whitelisted submitter address to submit a new task.
- r**ecord()**: This function finalizes and records the task after it has been verified and executed.

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
