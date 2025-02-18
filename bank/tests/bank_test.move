#[test_only]
module bank_package::bank_test {
    use sui::object::{Self, UID};
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context;
    use bank_package::Bank::{Self, AssetBank, Receipt};

    // Test-only coin type with store ability
    public struct TEST_COIN has drop, store {}

    const ALICE: address = @0xA11CE;
    const BOB: address = @0xB0B;

    #[test]
    fun test_basics() {
        let mut scenario = test_scenario::begin(ALICE);
        let test_coin = coin::mint_for_testing<TEST_COIN>(100, test_scenario::ctx(&mut scenario));
        let mut num_of_deposits = 0;
        let mut num_of_nfts = 0;
        let mut num_of_events = 0;
    
        // Initialize bank
        Bank::new<TEST_COIN>(test_scenario::ctx(&mut scenario));

        // Test deposit
        test_scenario::next_tx(&mut scenario, ALICE);
        {
            let mut bank = test_scenario::take_shared<AssetBank<TEST_COIN>>(&scenario);
            Bank::deposit(&mut bank, test_coin, test_scenario::ctx(&mut scenario));
            num_of_deposits = Bank::get_number_of_deposits<TEST_COIN>(&bank);
            
            // check that number of deposits updated
            assert!(num_of_deposits == 1);

            num_of_nfts = Bank::get_number_of_active_nfts<TEST_COIN>(&bank);
            // check that number of nfts updated
            assert!(num_of_nfts == 1);

            test_scenario::return_shared(bank);

            num_of_events = test_scenario::next_tx(&mut scenario, ALICE).num_user_events();
            // check that deposit event was emitted
            assert!(num_of_events == 1);
        };

        // Test withdrawal
        {
            let mut bank = test_scenario::take_shared<AssetBank<TEST_COIN>>(&scenario);
            let receipt = test_scenario::take_from_sender<Receipt<TEST_COIN>>(&scenario);

            Bank::withdraw(&mut bank, receipt, test_scenario::ctx(&mut scenario));
            
            num_of_events = test_scenario::next_tx(&mut scenario, ALICE).num_user_events();
            // check that withdraw event was emitted
            assert!(num_of_events == 1);
            
            // Take and check coin balance
            let coin = test_scenario::take_from_sender<Coin<TEST_COIN>>(&scenario);
            assert!(coin::value(&coin) == 100, 0);
            
            // check that number of deposits are the same
            let final_num_of_deposits = Bank::get_number_of_deposits(&bank);
            assert!(num_of_deposits == final_num_of_deposits);

            // check that number of nfts decreases by 1
            let final_num_of_nfts = Bank::get_number_of_active_nfts(&bank);
            assert!(num_of_nfts - 1 == final_num_of_nfts);

            test_scenario::return_shared(bank);
            test_scenario::return_to_sender(&scenario, coin);
        };

        test_scenario::end(scenario).num_user_events();
    }

    #[test]
    #[expected_failure(abort_code = Bank::E_INSUFFICIENT_BALANCE)]
    fun test_zero_deposit() {
        let mut scenario = test_scenario::begin(ALICE);
        let test_coin = coin::mint_for_testing<TEST_COIN>(0, test_scenario::ctx(&mut scenario));
        
        Bank::new<TEST_COIN>(test_scenario::ctx(&mut scenario));
        
        test_scenario::next_tx(&mut scenario, ALICE);
        {
            let mut bank = test_scenario::take_shared<AssetBank<TEST_COIN>>(&scenario);
            Bank::deposit(&mut bank, test_coin, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(bank);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = Bank::E_INSUFFICIENT_BANK_BALANCE)]
    fun test_insufficient_balance() {
        let mut scenario = test_scenario::begin(ALICE);
        let test_coin = coin::mint_for_testing<TEST_COIN>(50, test_scenario::ctx(&mut scenario));
        
        Bank::new<TEST_COIN>(test_scenario::ctx(&mut scenario));
        
        test_scenario::next_tx(&mut scenario, ALICE);
        {
            let mut bank = test_scenario::take_shared<AssetBank<TEST_COIN>>(&scenario);
            Bank::deposit(&mut bank, test_coin, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(bank);
        };

        test_scenario::next_tx(&mut scenario, ALICE);
        {
            let mut bank = test_scenario::take_shared<AssetBank<TEST_COIN>>(&scenario);
            let mut receipt = test_scenario::take_from_sender<Receipt<TEST_COIN>>(&scenario);
            // Modify receipt amount for testing
            Bank::test_modify_receipt_amount(&mut receipt, 100);
            Bank::withdraw(&mut bank, receipt, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(bank);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = Bank::E_UNAUTHORIZED_USER)]
    fun test_unauthorized_withdrawal() {
        let mut scenario = test_scenario::begin(ALICE);
        let test_coin = coin::mint_for_testing<TEST_COIN>(100, test_scenario::ctx(&mut scenario));
        
        Bank::new<TEST_COIN>(test_scenario::ctx(&mut scenario));
        
        // Deposit as ALICE
        test_scenario::next_tx(&mut scenario, ALICE);
        {
            let mut bank = test_scenario::take_shared<AssetBank<TEST_COIN>>(&scenario);
            Bank::deposit(&mut bank, test_coin, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(bank);
        };

        // Try to withdraw as BOB using ALICE's receipt
        test_scenario::next_tx(&mut scenario, BOB);
        {
            let mut bank = test_scenario::take_shared<AssetBank<TEST_COIN>>(&scenario);
            let receipt = test_scenario::take_from_address<Receipt<TEST_COIN>>(&scenario, ALICE);
            Bank::withdraw(&mut bank, receipt, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(bank);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_multiple_deposits() {
        let mut scenario = test_scenario::begin(ALICE);
        
        Bank::new<TEST_COIN>(test_scenario::ctx(&mut scenario));
        
        // First deposit
        test_scenario::next_tx(&mut scenario, ALICE);
        {
            let mut bank = test_scenario::take_shared<AssetBank<TEST_COIN>>(&scenario);
            let coin1 = coin::mint_for_testing<TEST_COIN>(100, test_scenario::ctx(&mut scenario));
            Bank::deposit(&mut bank, coin1, test_scenario::ctx(&mut scenario));
            assert!(Bank::get_number_of_deposits(&bank) == 1, 0);
            assert!(Bank::get_number_of_active_nfts(&bank) == 1, 1);
            test_scenario::return_shared(bank);
        };

        // Second deposit
        test_scenario::next_tx(&mut scenario, ALICE);
        {
            let mut bank = test_scenario::take_shared<AssetBank<TEST_COIN>>(&scenario);
            let coin2 = coin::mint_for_testing<TEST_COIN>(200, test_scenario::ctx(&mut scenario));
            Bank::deposit(&mut bank, coin2, test_scenario::ctx(&mut scenario));
            assert!(Bank::get_number_of_deposits(&bank) == 2, 2);
            assert!(Bank::get_number_of_active_nfts(&bank) == 2, 3);
            test_scenario::return_shared(bank);
        };

        // Verify receipt NFT numbers are sequential
        test_scenario::next_tx(&mut scenario, ALICE);
        {
            let receipt2 = test_scenario::take_from_sender<Receipt<TEST_COIN>>(&scenario);
            let receipt1 = test_scenario::take_from_sender<Receipt<TEST_COIN>>(&scenario);
            assert!(Bank::get_receipt_number(&receipt2) == 1, 4);
            assert!(Bank::get_receipt_number(&receipt1) == 0, 5);
            test_scenario::return_to_sender(&scenario, receipt1);
            test_scenario::return_to_sender(&scenario, receipt2);
        };
        
        test_scenario::end(scenario);
    }
}