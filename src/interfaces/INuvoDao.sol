// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface INuvoDao {
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        ProposalType indexed proposalType,
        ProposalCategory proposalCategory,
        string description
    );
    event Voted(uint256 proposalId, address voter, uint256 weight, uint256 quadraticVotes);
    event ProposalExecuted(uint256 id, bool passed);
    event FundingProposalExecuted(address recipient, uint256 amount, address token, string purpose);
    event BundleProposalExecuted(uint256 id, uint256[] executedProposalIds);
    event Upgraded(address newImplementation);
    event RewardClaimed(address claimer, uint256 amount);

    enum ProposalType {
        Basic,
        Funding,
        Governance,
        Bundle,
        Upgrade
    }

    enum ProposalCategory {
        Budget,
        Policy,
        Membership
    }

    struct Proposal {
        uint32 id;
        address proposer;
        ProposalType proposalType;
        ProposalCategory proposalCategory;
        bool executed;
        uint32 startTime;
        uint32 endTime;
        uint32 executionTime;
        uint256 voteCount;
        string description;
        bytes parameters; // Dynamic parameters for governance or funding proposal execution
    }

    struct FundingProposalParameters {
        address payable recipient;
        uint256 amount;
        address token; // Address of the ERC20 token, or address(0) for native cryptocurrency (e.g., ETH)
        string purpose;
    }
}
