#[allow(lint(self_transfer))]
module bank_package::Bank {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, value};
    use sui::event::{emit};

    /// Error codes for validation
    const E_INSUFFICIENT_BALANCE: u64 = 0;
    const E_INSUFFICIENT_BANK_BALANCE: u64 = 1;
    const E_UNAUTHORIZED_USER: u64 = 2;

    /// Event emitted when user deposits tokens
    public struct DepositReceived has copy, drop {
        bank_id: address,
        receipt_id: address,
        depositor: address,
        tokens_deposited: u64
    }

    /// Event emitted when user withdraws tokens    
    public struct WithdrawalMade has copy, drop {
        bank_id: address,
        receipt_id: address,
        depositor: address,
        tokens_received: u64
    }

    /// Holds coin balances and tracks total deposits and active NFTs
    public struct AssetBank<phantom T> has key {
        id: UID,
        number_of_deposits: u64,
        number_of_active_nfts: u64,
        coin_balance: Balance<T>
    }

    /// NFT representing deposit claim, stores amount and owner
    public struct Receipt<phantom T: store> has key {
        id: UID,
        nft_number: u64,
        depositor: address,
        tokens_deposited: u64
    }

    /// One-time witness for initialization
    public struct BANK has drop {}

    /// Creates shared bank object with zero balance
    fun init(_witness: BANK, ctx: &mut TxContext) {
        let bank = AssetBank<BANK> {
            id: object::new(ctx),
            number_of_deposits: 0,
            number_of_active_nfts: 0,
            coin_balance: balance::zero()
        };
        transfer::share_object(bank);
    }
   
    /// Test-only bank creation
    #[test_only]
    public fun new<T: store>(ctx: &mut TxContext) {
        let bank = AssetBank<T>{
            id: object::new(ctx),
            number_of_deposits: 0,
            number_of_active_nfts: 0,
            coin_balance: balance::zero()
        };

       transfer::share_object(bank);
    }

    /// Handles coin deposits and mints receipt NFTs
    public fun deposit<T: store>(bank: &mut AssetBank<T>, coin: Coin<T>, ctx: &mut TxContext){
        // Verify non-zero deposit
        assert!(value(&coin) > 0, E_INSUFFICIENT_BALANCE);

        // Update bank counters
        bank.number_of_deposits = bank.number_of_deposits + 1;
        bank.number_of_active_nfts = bank.number_of_active_nfts + 1; 
   
        // Create receipt with unique ID
        let receipt = Receipt<T> {
            id: object::new(ctx),
            nft_number: bank.number_of_deposits - 1,
            depositor: ctx.sender(),
            tokens_deposited: value(&coin)
        };
   
        // Emit deposit event
        emit(DepositReceived {
            bank_id: object::uid_to_address(&bank.id),
            receipt_id: object::uid_to_address(&receipt.id),
            depositor: ctx.sender(),
            tokens_deposited: value(&coin)
        });

        // Add coins to bank balance
        balance::join(&mut bank.coin_balance, coin::into_balance(coin));  
        // Transfer receipt to depositor
        transfer::transfer(receipt, tx_context::sender(ctx));    
    }

    /// Processes withdrawals using receipt NFTs
    public fun withdraw<T: store>(bank: &mut AssetBank<T>, receipt: Receipt<T>, ctx: &mut TxContext){
        let Receipt { id, nft_number: _, depositor, tokens_deposited } = receipt;
        
        // Verify sufficient balance and ownership
        assert!(balance::value(&bank.coin_balance) >= tokens_deposited, E_INSUFFICIENT_BANK_BALANCE);
        assert!(&depositor == ctx.sender(), E_UNAUTHORIZED_USER);

        // Update active NFT count
        bank.number_of_active_nfts = bank.number_of_active_nfts - 1;
        
        // Create coin from bank balance
        let coin = coin::from_balance(
            balance::split(&mut bank.coin_balance, tokens_deposited),
            ctx
        );

        // Emit withdrawal event
        emit(WithdrawalMade{
            bank_id: object::uid_to_address(&bank.id),
            receipt_id: object::uid_to_address(&id),
            depositor: ctx.sender(),
            tokens_received: value(&coin)
        });

        // Transfer coins and cleanup
        transfer::public_transfer(coin, depositor);
        object::delete(id);
    }

    /// Test helper to modify receipt amounts
    #[test_only]
    public fun test_modify_receipt_amount<T: store>(receipt: &mut Receipt<T>, new_amount: u64) {
        receipt.tokens_deposited = new_amount;
    }

    /// Gets sequential NFT number
    #[test_only]
    public fun get_receipt_number<T: store>(receipt: &Receipt<T>): u64 {
        receipt.nft_number
    }

    /// Gets total deposits count
    public fun get_number_of_deposits<T>(bank: &AssetBank<T>): u64 {
        bank.number_of_deposits
    }

    /// Gets count of unredeemed receipts
    public fun get_number_of_active_nfts<T>(bank: &AssetBank<T>): u64 {
        bank.number_of_active_nfts
    }
}