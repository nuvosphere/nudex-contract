const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DepositManager - Edge Cases", function () {
  let depositManager, addr1, addr2;

  beforeEach(async function () {
    [addr1, addr2] = await ethers.getSigners();

    // Deploy DepositManager
    const DepositManager = await ethers.getContractFactory("DepositManager");
    depositManager = await DepositManager.deploy();
    await depositManager.deployed();
  });

  it("Should return an empty array if no deposits exist for an address", async function () {
    const deposits = await depositManager.getDeposits(addr1.address);
    expect(deposits.length).to.equal(0);
  });

  it("Should correctly store and retrieve a deposit with minimal data", async function () {
    const targetAddress = addr1.address;
    const amount = ethers.utils.parseUnits("1", 18);
    const txInfo = "0x"; // Minimal transaction info
    const chainId = 0; // Edge case chain ID
    const extraInfo = "0x"; // Minimal extra info

    await depositManager.recordDeposit(targetAddress, amount, txInfo, chainId, extraInfo);

    const deposits = await depositManager.getDeposits(targetAddress);
    expect(deposits.length).to.equal(1);
    expect(deposits[0].amount).to.equal(amount);
    expect(deposits[0].txInfo).to.equal(txInfo);
    expect(deposits[0].chainId).to.equal(chainId);
    expect(deposits[0].extraInfo).to.equal(extraInfo);
  });

  it("Should correctly handle multiple deposits with the same transaction info", async function () {
    const targetAddress = addr1.address;
    const amount1 = ethers.utils.parseUnits("100", 18);
    const amount2 = ethers.utils.parseUnits("200", 18);
    const txInfo = "0x1234"; // Same transaction info for both deposits
    const chainId = 1;
    const extraInfo1 = "0x5678";
    const extraInfo2 = "0x5432";

    await depositManager.recordDeposit(targetAddress, amount1, txInfo, chainId, extraInfo1);
    await depositManager.recordDeposit(targetAddress, amount2, txInfo, chainId, extraInfo2);

    const deposits = await depositManager.getDeposits(targetAddress);
    expect(deposits.length).to.equal(2);
    expect(deposits[0].amount).to.equal(amount1);
    expect(deposits[0].txInfo).to.equal(txInfo);
    expect(deposits[0].chainId).to.equal(chainId);
    expect(deposits[0].extraInfo).to.equal(extraInfo1);
    expect(deposits[1].amount).to.equal(amount2);
    expect(deposits[1].txInfo).to.equal(txInfo);
    expect(deposits[1].chainId).to.equal(chainId);
    expect(deposits[1].extraInfo).to.equal(extraInfo2);
  });
});
