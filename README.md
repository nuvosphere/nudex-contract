# nudex-contract

Smart contracts used by nuDex deposits and withdraw

## Deployed Contracts

> Goat Mainnet (production)

| Contract           | Address                                    |
| ------------------ | ------------------------------------------ |
| NuvoToken          | 0x01c36030282b247A9ce9954B1CedF69b7947f754 |
| EntryPoint         | 0xe57B81AFdfC1d9851bfD4217D0C321A7Cdd37f36 |
| NuvoLock           | 0x29F50302ebaa860a77b3A6ACe60F6835Af91aAA5 |
| TaskManager        | 0x33b82a4FdbC915298551212443aD16f4c9fbF154 |
| ParticipantHandler | 0x189334cFbb33BC7C2eDB45C2f84e049fFf66DE67 |
| AccountHandler     | 0xc2c9F2442B93ea38d661E4DFd8a0276acCdd1347 |
| AssetManager       | 0x2117dF43b088d9B525396b20591d9Ec273A63838 |
| FundsHandler       | 0x06Bd0eC86aB9fC28eAa9C09E457C6c75d1421127 |
| NudexAuthorize     | 0xd2b22A5557adF344184eBCF36768922a1631B2d6 |

> Goat Testnet (dev)

| Contract           | Address                                    |
| ------------------ | ------------------------------------------ |
| NuvoToken          | 0xb1de22C4DAAcB986d8bD39Fb0FCC9D54C511002E |
| EntryPoint         | 0x98efef3C3638E5c8606347788ae70B2eb10b066b |
| NuvoLock           | 0xc06Cd48d552B69aF37387d16BB21A03Cf1338D40 |
| AssetManager       | 0xdB5D5871167A3f390f0e192646975b3cd3CDAED0 |
| TaskManager        | 0x23BD1333eC6994C1863a04f50B193C0A847a38b8 |
| ParticipantHandler | 0x3Eec9D2eE8F222F28711e0E8aE6231b5c48F6260 |
| AccountHandler     | 0x876f527aA37d8D46930420B8486dA5067843aa42 |
| FundsHandler       | 0xd8Ee78cC35E0E54bb85eD2ACF521dD223F46d58C |

submitter: 0x1D2cd50A3cF3c55a7982AD54F9f364C1e953Bc57  
participant 0 address: 0x3a818294ca1F3C27d7588b123Ec43F2546fa07f4  
participant 1 address: 0x04d9389Cf937b1e6F2258d842e7237E955d6ab04  
participant 2 address: 0xf6D37CE75dB465DcDb4c7097bEB9c1D46b171037

> Goat Testnet (test)

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

## Task Workflow

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

## Becoming a Valid Participant

To become a valid participant, a user must lock **NUBI** tokens into the **NuvoLock** contract. This can be done using one of the following methods:

1. `lock(uint256 _amount, uint32 _period)`

Locks **NUBI** tokens in the contract.

- \_amount: The amount of NUBI tokens to lock. Must be greater than `minLockAmount`.
- \_period: The locking period in seconds. Must be greater than `minLockPeriod`.

Before calling this function, the user must first approve the NuvoLock contract to spend at least \_amount of NUBI tokens.

2. `lockWithPermit(address _owner, uint256 _amount, uint32 _period, uint8 _v, bytes32 _r, bytes32 _s)`

Locks **NUBI** tokens using an off-chain signature, allowing the user to skip the approval step.

- \_owner: The address of the user locking the tokens.
- \_amount: The amount of NUBI tokens to lock (must be greater than minLockAmount).
- \_period: The locking period in seconds (must be greater than minLockPeriod).
- \_v, \_r, \_s: The signature parameters generated according to the ERC20Permit standard.

This function enables gasless approval using the ERC20Permit mechanism, reducing the number of transactions required.
