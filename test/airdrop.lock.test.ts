/** @format */

import { ethers } from "hardhat";
import { AirdropLock, TestToken } from "../typechain-types";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { Addressable } from "ethers";

const LOCKUP_PERIOD = 60 * 60 * 24 * 30 * 3;
const IMMEDIATE_CLAIM_PERCENT = 2500;
const PERCENT_PRECISION = 10000;

async function deployFixture() {
  const [owner, tester1, tester2, tester3] = await ethers.getSigners();

  const testToken = await ethers.deployContract("TestToken", ["Test Token", "TST"]);
  testToken.waitForDeployment();

  return { testToken, owner, tester1, tester2, tester3 };
}

async function deployAirdropLock(token: string | Addressable) {
  const startTimestamp = (await ethers.provider.getBlock("latest"))!.timestamp + 60 * 5;
  const endTimestamp = startTimestamp + 60 * 5;
  const airdropLock = await ethers.deployContract("AirdropLock", [
    token,
    startTimestamp,
    endTimestamp,
    LOCKUP_PERIOD,
    IMMEDIATE_CLAIM_PERCENT,
  ]);
  airdropLock.waitForDeployment();

  return airdropLock;
}

describe("AirdropLock", () => {
  let testToken: TestToken;
  let owner: any;
  let tester1: any;
  let tester2: any;
  let tester3: any;
  let startTimestamp: number;
  let endTimestamp: number;

  before(async () => {
    ({ testToken, owner, tester1, tester2, tester3 } = await loadFixture(deployFixture));
    startTimestamp = (await ethers.provider.getBlock("latest"))!.timestamp + 60 * 5;
    endTimestamp = startTimestamp + 60 * 5;
  });

  describe("Deployment", () => {
    let airdropLock: AirdropLock;

    it("Should not deploy contract if token address is zero", async () => {
      expect(
        ethers.deployContract("AirdropLock", [
          ethers.ZeroAddress,
          startTimestamp,
          endTimestamp,
          LOCKUP_PERIOD,
          IMMEDIATE_CLAIM_PERCENT,
        ])
      ).to.be.revertedWith("Airdrop: Invalid token address");
    });

    it("Should not deploy contract if invalid timestamp", async () => {
      expect(
        ethers.deployContract("AirdropLock", [
          testToken.target,
          startTimestamp,
          startTimestamp - 60,
          LOCKUP_PERIOD,
          IMMEDIATE_CLAIM_PERCENT,
        ])
      ).to.be.revertedWith("Airdrop: Invalid start and end timestamp");

      expect(
        ethers.deployContract("AirdropLock", [
          testToken.target,
          startTimestamp,
          endTimestamp,
          60,
          IMMEDIATE_CLAIM_PERCENT,
        ])
      ).to.be.revertedWith("Airdrop: Invalid lockup period");
    });

    it("Should not deploy contract if invalid immediate claim percent", async () => {
      expect(
        ethers.deployContract("AirdropLock", [testToken.target, startTimestamp, endTimestamp, 60, 12000])
      ).to.be.revertedWith("Airdrop: Invalid immediate claim percentage");
    });

    it("Should deploy AirdropLock contract", async () => {
      airdropLock = await deployAirdropLock(testToken.target);
      expect(airdropLock.target).to.be.ok;
    });

    it("Should grant admin role to deployer", async () => {
      const ADMIN_ROLE = await airdropLock.ADMIN_ROLE();
      const HAS_ROLE = await airdropLock.hasRole(ADMIN_ROLE, owner.address);
      expect(HAS_ROLE).to.be.true;
    });
  });

  describe("Airdrop Data CRUD", () => {
    let airdropLock: AirdropLock;

    before(async () => {
      airdropLock = await deployAirdropLock(testToken.target);
    });

    it("Should insert airdrop data", async () => {
      expect(await airdropLock.insertAirdropData(tester1.address, ethers.parseEther("100"))).to.be.ok;
    });

    it("Should batch insert airdrop data", async () => {
      const addresses = [tester2.address, tester3.address];
      const amounts = [ethers.parseEther("100"), ethers.parseEther("200")];
      expect(await airdropLock.batchInsertAirdropData(addresses, amounts)).to.be.ok;
    });

    it("Should not insert airdrop data if not admin", async () => {
      expect(
        airdropLock.connect(tester1).insertAirdropData(tester2.address, ethers.parseEther("100"))
      ).to.be.revertedWith("AccessControl: sender must have the admin role");
    });

    it("Should update airdrop data", async () => {
      expect(await airdropLock.updateAirdropData(tester1.address, ethers.parseEther("100"))).to.be.ok;
    });

    it("Should not update airdrop data if not exist", async () => {
      expect(airdropLock.updateAirdropData(tester2.address, ethers.parseEther("100"))).to.be.revertedWith(
        "Airdrop: Airdrop data not found"
      );
    });

    it("Should not update airdrop data if not admin", async () => {
      expect(
        airdropLock.connect(tester1).updateAirdropData(tester1.address, ethers.parseEther("100"))
      ).to.be.revertedWith("AccessControl: sender must have the admin role");
    });

    it("Should delete airdrop data", async () => {
      expect(airdropLock.deleteAirdropData(tester1.address)).to.be.ok;
    });

    it("Should not delete airdrop data if not exist", async () => {
      expect(airdropLock.deleteAirdropData(tester2.address)).to.be.revertedWith("Airdrop: Airdrop data not found");
    });

    it("Should not delete airdrop data if not admin", async () => {
      expect(airdropLock.connect(tester1).deleteAirdropData(tester1.address)).to.be.revertedWith(
        "AccessControl: sender must have the admin role"
      );
    });
  });

  describe("Airdrop claim immediately", () => {
    let airdropLock: AirdropLock;

    before(async () => {
      airdropLock = await deployAirdropLock(testToken.target);
      testToken.mint(airdropLock.target, ethers.parseEther("1000"));
      await airdropLock.insertAirdropData(tester1.address, ethers.parseEther("100"));
    });

    it("Should not claim before airdrop start", async () => {
      expect(airdropLock.connect(tester1).claimAirdrop()).to.be.revertedWith("Airdrop: Airdrop not started");
    });

    it("Should claim airdrop immediately", async () => {
      await time.increase(60 * 6);
      const beforeBalance = await testToken.balanceOf(tester1.address);
      const airdropIndex = await airdropLock.airdropIndex(tester1.address);
      const airdropInfo = await airdropLock.airdropInfo(airdropIndex);

      expect(await airdropLock.connect(tester1).claimAirdrop()).to.be.ok;

      const afterBalance = await testToken.balanceOf(tester1.address);
      const expectedBalance =
        beforeBalance + (airdropInfo.amount * BigInt(IMMEDIATE_CLAIM_PERCENT)) / BigInt(PERCENT_PRECISION);
      expect(afterBalance).to.eq(expectedBalance);
    });

    it("Should not claim airdrop if not exist", async () => {
      expect(airdropLock.connect(tester2).claimAirdrop()).to.be.revertedWith("Airdrop: Airdrop data not found");
    });

    it("Should not claim airdrop if already claimed", async () => {
      expect(airdropLock.connect(tester1).claimAirdrop()).to.be.revertedWith("Airdrop: Airdrop already claimed");
    });

    it("Shoudl not claim airdrop after end timestamp", async () => {
      await time.increase(60 * 6);
      expect(airdropLock.connect(tester1).claimAirdrop()).to.be.revertedWith("Airdrop: Airdrop ended");
    });
  });

  describe("Airdrop lockup", () => {
    let airdropLock: AirdropLock;

    before(async () => {
      airdropLock = await deployAirdropLock(testToken.target);
      testToken.mint(airdropLock.target, ethers.parseEther("1000"));
      const addresses = [tester1.address, tester2.address];
      const amounts = [ethers.parseEther("100"), ethers.parseEther("200")];
      await airdropLock.batchInsertAirdropData(addresses, amounts);
    });

    it("Should lock up only airdrop opened", async () => {
      expect(airdropLock.connect(tester1).lockup()).to.be.revertedWith("Airdrop: Airdrop not started");
    });

    it("Should not lock up if not exist", async () => {
      expect(airdropLock.connect(tester3).lockup()).to.be.revertedWith("Airdrop: Airdrop data not found");
    });

    it("Should not lock up after claim", async () => {
      await time.increase(60 * 6);
      await airdropLock.connect(tester1).claimAirdrop();
      expect(airdropLock.connect(tester1).lockup()).to.be.revertedWith("Airdrop: Airdrop already claimed");
    });

    it("Should lock up", async () => {
      expect(await airdropLock.connect(tester2).lockup()).to.be.ok;
    });

    it("Should claim lockup amount after lockup period", async () => {
      await time.increase(LOCKUP_PERIOD);
      const beforeBalance = await testToken.balanceOf(tester2.address);
      const airdropIndex = await airdropLock.airdropIndex(tester2.address);
      const airdropInfo = await airdropLock.airdropInfo(airdropIndex);

      expect(await airdropLock.connect(tester2).claimLockup()).to.be.ok;

      const afterBalance = await testToken.balanceOf(tester2.address);
      const expectedBalance = beforeBalance + airdropInfo.amount;
      expect(afterBalance).to.eq(expectedBalance);
    });

    it("Should not lockup after claim lockup amount", async () => {
      expect(airdropLock.connect(tester2).lockup()).to.be.revertedWith("Airdrop: Airdrop already claimed");
    });

    it("Should not lock up after end timestamp", async () => {
      await time.increase(60 * 6);
      expect(airdropLock.connect(tester1).lockup()).to.be.revertedWith("Airdrop: Airdrop ended");
    });
  });
});
