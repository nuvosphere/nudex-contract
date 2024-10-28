## Account creation
1. User request deposit address through nuDex
2. Nudex checks whether the deposit addresss of the source chain and asset is already created by query the accountmanager contract 
3. if address is not available, nudex inserts an address creation task to the contract. TSS node will monitor the events and pick up the task, start the vote and create the address. the current submitter will submit the result and record it in account manager contract.
 
## Deposit
1. a monitoring service will monitor all addresses in the account manager contract. If a deposit event is detected, the service will insert a deposit request task to the contract
2. the tss nodes will pick up the task and verify the deposit. once verfiied, the current submitter will collect the signatures, submit the info back to the contract and add to the deposited assets of the source chain in the deposit contract.
3. the smart contract then will mint the corresponding inscription assets to reflect the deposit. (handled by Max)
4. nudex will monitor the deposit event from the contract and update the databases.

## Consolidation
1. a monitoring service will monitor the balances of addresses and decide whether a consolidation is required
2. a consolidation task is submitted to the operation contract
3. tss nodes will verify the request adn decide whether to accept or reject
4. if accepted, the tss node will engage either cross chain or inchain consolidation, once confirmed, submit the consolidation result to the smart contract and update the deposit records.

## Withdraw
1. users or nudex will submit a withdraw request to a smart contract. the smart ccontract verifies whether the corresponding inscription assets has been transferred to the smart contract, burn the assets and insert a withdraw task to the operation. 
2. TSS nodes verifies the balances of the target chain and whether users has indeeded got inscriptions transfered and burned, then submit the transaction with multisig. the current submitter will submit the txid back to the smart contract so that nudex can monitor the progress.
3. if transaction is dropped, nudex may request resubmission so that tss nodes can resubmit after verification.