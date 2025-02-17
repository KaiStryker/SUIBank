module bank::Bank {
    use sui::object::{Self, UID, freeze_object, new};
    use sui::transfer;
    use sui::balance::{Self, Balance, zero, from_coin};
    use sui::coin::{Self, Coin, value};
    use sui::event::{Self, emit};
    use sui::address::Address;
    use sui::tx_context::TxContext;

    // event for deposit function 
    const E_INSUFFICIENT_BALANCE: u64 = 0;

    public struct DepositReceived has copy, drop {
            bank_id: UID,
            receipt_id: UID,
            depositor: Address,
            tokens_deposited: u64
        }

    // Define the bank asset
    public struct AssetBank<T: store> has store, key {
        id: UID,
        number_of_deposits: u64,
        number_of_active_nfts: u64,
        coin_balance: Balance<T>

    }

   public struct Receipt<T: store> has store, key {
      id: UID,
      nft_number: u64,
      depositor: Address,
      tokens_deposited: u64
   }

    // Initialize the bank asset and share it
    public fun init<T>(ctx: &mut TxContext) {
        let bank = AssetBank<T> {
            id: new(ctx),
            number_of_deposits: 0,
            number_of_active_nfts: 0,
            coin_balance: zero()
        };
        transfer::share_object(bank);
    }

  public fun deposit<T: store>(bank: &mut AssetBank<T>, coin: Coin<T>, ctx: &mut TxContext){
      assert!(value(&coin) > 0, E_INSUFFICIENT_BALANCE);
      bank.coin_balance.deposit(coin);
      bank.number_of_deposits += 1;
      bank.number_of_active_nfts += 1; 
  
      let receipt = Receipt<T> {
          id: new(ctx),
          nft_number: bank.number_of_deposits,
          depositor: ctx.sender(),
          tokens_deposited: value(&coin)
      };
  
      emit(DepositReceived {
              bank_id: bank.id,
              receipt_id: receipt.id,
              depositor: ctx.sender(),
              tokens_deposited: value(&coin)
          });

       freeze_object(receipt);   
      transfer::transfer(receipt, ctx.sender());   
  }
}
