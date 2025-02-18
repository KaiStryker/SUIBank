#[test_only]
module bank::bank_test {
    use sui::object::{UID, new};
    use sui::transfer;
    use sui::balance::{Balance, zero, from_coin};
    use sui::coin::{Coin, value, from_balance};
    use sui::event;
    use sui::tx_context::TxContext;
    use sui::test_scenario;
    use sui::address::Address;
    use sui::test_scenario::TestScenario;
    use bank::Bank::{AssetBank, Receipt, DepositReceived, WithdrawalMade, init, deposit, withdraw};

    /// Helper function to create a test context
    fun test_ctx() : TxContext {
        test_scenario::new_tx_context()
    }

    /// Helper function to create a test coin
    fun test_coin<T: store>(amount: u64, ctx: &mut TxContext): Coin<T> {
        from_balance(Balance { value: amount }, ctx)
    }

    /// Test bank initialization
    #[test]
    public fun test_init() {
        let ctx = test_ctx();
        let bank = init<SUI>(&mut ctx);
        assert!(value(&bank.coin_balance) == 0, 0);
        assert!(bank.number_of_deposits == 0, 1);
        assert!(bank.number_of_active_nfts == 0, 2);
    }

    /// Test deposit and event emission
    #[test]
    public fun test_deposit_event() {
        let ctx = test_ctx();
        let mut bank = init<SUI>(&mut ctx);
        let coin = test_coin<SUI>(100, &mut ctx);

        let events_before = event::count(&ctx);
        deposit(&mut bank, coin, &mut ctx);
        let events_after = event::count(&ctx);

        // Verify deposit event was emitted
        assert!(events_after == events_before + 1, 0);

        // Verify event data
        let evt: DepositReceived = event::get(events_before, &ctx);
        assert!(evt.tokens_deposited == 100, 1);
        assert!(evt.depositor == ctx.sender(), 2);
    }

    /// Test withdrawal and event emission
    #[test]
    public fun test_withdraw_event() {
        let ctx = test_ctx();
        let mut bank = init<SUI>(&mut ctx);
        let coin = test_coin<SUI>(100, &mut ctx);

        deposit(&mut bank, coin, &mut ctx);

        let receipt = Receipt<SUI> {
            id: new(&mut ctx),
            nft_number: 1,
            depositor: ctx.sender(),
            tokens_deposited: 100
        };

        let events_before = event::count(&ctx);
        withdraw(&mut bank, receipt, &mut ctx);
        let events_after = event::count(&ctx);

        // Verify withdrawal event was emitted
        assert!(events_after == events_before + 1, 0);

        // Verify event data
        let evt: WithdrawalMade = event::get(events_before, &ctx);
        assert!(evt.tokens_received == 100, 1);
        assert!(evt.depositor == ctx.sender(), 2);
    }

    /// Test deposit with zero value (should fail)
    #[test]
    public fun test_zero_deposit_fail() {
        let ctx = test_ctx();
        let mut bank = init<SUI>(&mut ctx);
        let coin = test_coin<SUI>(0, &mut ctx);

        // Expect deposit to fail
        deposit(&mut bank, coin, &mut ctx);
    }

    /// Test withdrawal with insufficient funds (should fail)
    #[test]
    public fun test_insufficient_funds_fail() {
        let ctx = test_ctx();
        let mut bank = init<SUI>(&mut ctx);
        let coin = test_coin<SUI>(50, &mut ctx);

        deposit(&mut bank, coin, &mut ctx);

        let receipt = Receipt<SUI> {
            id: new(&mut ctx),
            nft_number: 1,
            depositor: ctx.sender(),
            tokens_deposited: 100 // Trying to withdraw more than deposited
        };

        // Expect withdrawal to fail
        withdraw(&mut bank, receipt, &mut ctx);
    }

    /// Test withdrawal with an invalid receipt (should fail)
    #[test]
    public fun test_invalid_receipt_fail() {
        let ctx = test_ctx();
        let mut bank = init<SUI>(&mut ctx);

        // Creating a receipt without making a deposit
        let receipt = Receipt<SUI> {
            id: new(&mut ctx),
            nft_number: 1,
            depositor: ctx.sender(),
            tokens_deposited: 100
        };

        // Expect withdrawal to fail
        withdraw(&mut bank, receipt, &mut ctx);
    }

    /// Test using another user's receipt to withdraw (should fail)
    #[test]
    public fun test_unauthorized_withdraw_fail() {
        let ctx = test_ctx();
        let mut bank = init<SUI>(&mut ctx);
        let coin = test_coin<SUI>(100, &mut ctx);

        deposit(&mut bank, coin, &mut ctx);

        let receipt = Receipt<SUI> {
            id: new(&mut ctx),
            nft_number: 1,
            depositor: Address::random(), // Someone else
            tokens_deposited: 100
        };

        // Expect withdrawal to fail
        withdraw(&mut bank, receipt, &mut ctx);
    }
}
