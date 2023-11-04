
/* What is this ? 
This Rust code uses the ink! language to define a smart contract for a real estate sale. It includes the same functionality as the Solidity contract, such as verifying the title, placing funds in escrow, finalizing the sale, refunding the buyer, and getting the property status */


/* this contract would require a Substrate-based blockchain that supports the ink! smart contract language. The Ethereum Virtual Machine (EVM) does not natively support Rust contracts, so this contract would not be deployable on Ethereum without a Substrate-EVM compatibility layer. */

#![cfg_attr(not(feature = "std"), no_std)]

use ink_lang as ink;

#[ink::contract]
mod real_estate_sale {
    use ink_storage::{
        traits::{PackedLayout, SpreadLayout},
        Lazy,
    };

    /// Define events
    #[ink(event)]
    pub struct PropertySold {
        #[ink(topic)]
        buyer: Option<AccountId>,
        price: Balance,
    }

    #[ink(event)]
    pub struct FundsHeldInEscrow {
        amount: Balance,
    }

    #[ink(event)]
    pub struct TitleVerified {
        status: bool,
    }

    #[ink(storage)]
    pub struct RealEstateSale {
        seller: Lazy<AccountId>,
        buyer: Option<AccountId>,
        property_price: Balance,
        is_sold: bool,
        title_verified: bool,
        funds_in_escrow: bool,
        due_diligence_period: Timestamp,
        sale_completion_date: Option<Timestamp>,
    }

    impl RealEstateSale {
        /// Constructor to initialize the contract with the seller's address, property price, and due diligence period
        #[ink(constructor)]
        pub fn new(seller: AccountId, property_price: Balance, due_diligence_days: u64) -> Self {
            let due_diligence_period = Self::env().block_timestamp() + due_diligence_days * 86400000;
            Self {
                seller: Lazy::new(seller),
                buyer: None,
                property_price,
                is_sold: false,
                title_verified: false,
                funds_in_escrow: false,
                due_diligence_period,
                sale_completion_date: None,
            }
        }

        /// Function to verify the property title
        #[ink(message)]
        pub fn verify_title(&mut self) {
            assert_eq!(self.env().caller(), *self.seller);
            self.title_verified = true;
            self.env().emit_event(TitleVerified { status: true });
        }

        /// Function to place funds in escrow
        #[ink(message, payable)]
        pub fn place_funds_in_escrow(&mut self) {
            assert!(!self.is_sold, "Property already sold.");
            let caller = self.env().caller();
            let transferred_balance = self.env().transferred_balance();
            assert_eq!(transferred_balance, self.property_price, "Incorrect amount");
            assert!(self.title_verified, "Title must be verified before transaction.");
            self.funds_in_escrow = true;
            self.buyer = Some(caller);
            self.env().emit_event(FundsHeldInEscrow { amount: transferred_balance });
        }

        /// Function to confirm due diligence is completed and finalize the sale
        #[ink(message)]
        pub fn finalize_sale(&mut self) {
            assert_eq!(self.env().caller(), *self.seller);
            assert!(self.funds_in_escrow, "Funds must be in escrow to finalize the sale.");
            assert!(self.env().block_timestamp() <= self.due_diligence_period, "Due diligence period has expired.");
            self.is_sold = true;
            self.sale_completion_date = Some(self.env().block_timestamp());
            ink_env::transfer(*self.buyer.as_ref().unwrap(), self.property_price).expect("Transfer failed");
            self.env().emit_event(PropertySold { buyer: self.buyer, price: self.property_price });
        }

        /// Function to return funds if due diligence fails
        #[ink(message)]
        pub fn refund_buyer(&mut self) {
            assert_eq!(self.env().caller(), *self.seller);
            assert!(self.funds_in_escrow, "No funds in escrow.");
            assert!(self.env().block_timestamp() > self.due_diligence_period, "Due diligence period not yet expired.");
            assert!(!self.is_sold, "Sale has already been finalized.");
            self.funds_in_escrow = false;
            ink_env::transfer(*self.buyer.as_ref().unwrap(), self.property_price).expect("Refund failed");
        }

        /// Function to get the status of the property
        #[ink(message)]
        pub fn get_property_status(&self) -> (bool, bool, Option<Timestamp>) {
            (self.is_sold, self.title_verified, self.sale_completion_date)
        }
    }
}
