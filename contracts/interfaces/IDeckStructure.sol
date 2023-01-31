// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDeckStructure {
    struct BuyBackFee {
        bool active;
        uint16 feeRate;
    }

    struct ServiceFee {
        address paymentToken;
        uint256 feeAmount;
        string serviceFeeName;
        bool active;
        uint16 burnPercent;
    }

    struct WinningDistribution {
        uint16 lenderRate;
        uint16 borrowerRate;
        uint16 burnRate;
    }

    struct DeckLPInfo {
        address[] collectionAddresses;
        uint256[] tokenIds;
        /// @dev If this deckLp is receipt deckLp, `borrowedDeckLpId` shows borrowed deckLpId.
        uint256 borrowedDeckLpId;
        bool listedLend;
        bool lend;
        bool lendDeckLp;
    }

    struct LendInfo {
        address lender;
        address borrower;
        address paymentToken;
        uint256 dailyInterest;
        uint256 prepayAmount;
        uint256 borrowedTimestamp;
        uint256 borrowDuration;
        WinningDistribution winDistributionRate;
        bool prepay;
    }   
}