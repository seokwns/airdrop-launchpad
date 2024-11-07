import { ethers } from "hardhat";
import { ChuruLaunchpad, TestToken } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { expect } from "chai";
import { mine, mineUpTo } from "@nomicfoundation/hardhat-network-helpers";

describe("Launchpad", () => {
  let launchpad: ChuruLaunchpad;
  let deployer: HardhatEthersSigner;
  let tester1: HardhatEthersSigner;
  let tester2: HardhatEthersSigner;
  let tester3: HardhatEthersSigner;
  let token: TestToken;

  let launchpadAmount = ethers.parseEther("10000000");
  let claimRatio = ethers.parseEther("100");
  let startBlock: number;
  let endBlock: number;

  const PERCENT_PRECISION = 1e8;

  before(async () => {
    [deployer, tester1, tester2, tester3] = await ethers.getSigners();
    token = await ethers.deployContract("TestToken", ["Test Token", "TST"]);
    await token.waitForDeployment();

    await token.mint(deployer.address, ethers.parseEther("20000000"));
  });

  it("Should deploy contract", async () => {
    [deployer, tester1, tester2, tester3] = await ethers.getSigners();
    launchpad = await ethers.deployContract("ChuruLaunchpad", [token.target]);
    await launchpad.waitForDeployment();
  });

  it("Should enroll launchpad info", async () => {
    startBlock = (await ethers.provider.getBlockNumber()) + 10;
    endBlock = startBlock + 100;
    await token.approve(launchpad.target, launchpadAmount);
    await expect(launchpad.enroll(launchpadAmount, claimRatio, startBlock, endBlock)).to.be.emit(launchpad, "Enrolled");
  });

  it("Should update start and end block", async () => {
    startBlock = endBlock + 100;
    endBlock = startBlock + 100;
    await expect(launchpad.updatePeriod(startBlock, endBlock)).to.be.emit(launchpad, "PeriodUpdated");
  });

  it("Should update churu per ace", async () => {
    claimRatio = ethers.parseEther("200");
    await expect(launchpad.updateChuruPerAce(claimRatio)).to.be.emit(launchpad, "ClaimRatioUpdated");
  });

  it("Should update launchpad amount", async () => {
    launchpadAmount = ethers.parseEther("20000000");
    await token.approve(launchpad.target, launchpadAmount);
    await expect(launchpad.updateLaunchpadAmount(launchpadAmount)).to.be.emit(launchpad, "LaunchpadAmountUpdated");

    const amount = await launchpad.amount();
    expect(amount).to.equal(launchpadAmount);
  });

  it("Should not claim before launchpad starts", async () => {
    expect(launchpad.claim()).to.be.revertedWith("Launchpad: not started");
  });

  it("Should claim after launchpad starts", async () => {
    await mineUpTo(startBlock);
    const value = ethers.parseEther("100");
    const beforeBalance = await token.balanceOf(tester1.address);
    await expect(launchpad.connect(tester1).claim({ value })).to.be.emit(launchpad, "Claimed");

    // 앞선 테스트에서 claimRatio 를 200으로 변경했으므로, 100 * 200 / 1 = 20000 이어야 함
    const expected = ethers.parseEther("20000");
    const afterBalance = await token.balanceOf(tester1.address);
    expect(afterBalance).to.equal(expected);

    const launchpadBalance = await token.balanceOf(launchpad.target);
    expect(launchpadBalance).to.equal(launchpadAmount - afterBalance);
  });

  it("Should get progress", async () => {
    const progress = await launchpad.getProgress();
    const expected = ((launchpadAmount - ethers.parseEther("20000")) * BigInt(PERCENT_PRECISION)) / launchpadAmount;
    expect(progress).to.equal(expected);
  });

  it("Should not claim after launchpad ends", async () => {
    await mineUpTo(endBlock);
    expect(launchpad.claim()).to.be.revertedWith("Launchpad: ended");
  });

  it("Should collect remaining tokens", async () => {
    const beforeBalance = await token.balanceOf(deployer.address);
    const beforeLaunchpadBalance = await token.balanceOf(launchpad.target);
    await expect(launchpad.close()).to.be.emit(launchpad, "Closed");

    const afterBalance = await token.balanceOf(deployer.address);
    const afterLaunchpadBalance = await token.balanceOf(launchpad.target);
    expect(afterLaunchpadBalance).to.equal(0);
    expect(afterBalance).to.equal(beforeBalance + beforeLaunchpadBalance);
  });
});
