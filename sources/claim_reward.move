/*
/// Module: claim_reward
module claim_reward::claim_reward;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions
module claim_reward::claim_reward {
use sui::coin::{Self, Coin};
use lending_core::incentive_v2::{Incentive as IncentiveV2};
use lending_core::incentive_v3::{Self, Incentive, RewardFund};
use lending_core::account::{AccountCap};
use lending_core::storage::Storage;
use lending_core::lending;
use std::ascii::String;
use std::type_name;
use sui::event;
use lending_core::pool::{Pool};
use sui::clock::{Clock};
use sui::transfer::{Self};
use oracle::oracle::{PriceOracle};
use sui::tx_context::{Self, TxContext};


    public struct Vault has key {
        id: UID,
        account_cap: AccountCap,
        sui_index: u8,
        usdc_index: u8
    }

    public struct RewardClaimable has copy, drop {
        asset_coin_type: String,
        reward_coin_type: String,
        user_claimable_reward: u256,
        user_claimed_reward: u256
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let vault = Vault {
            id: object::new(ctx),
            account_cap: lending::create_account(ctx),
            sui_index: 0,
            usdc_index: 1,
        };
        transfer::share_object(vault);
    }

    //存款
    public entry fun deposit<A> (
        vault: &Vault,
        deposit_coin: Coin<A>,
        storage: &mut Storage,
        pool_a: &mut Pool<A>,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        clock: &Clock
    ) {
        lending_core::incentive_v3::deposit_with_account_cap(clock, storage, pool_a, vault.sui_index, deposit_coin, incentive_v2, incentive_v3, &vault.account_cap)
    }

    //查看可取奖励
    public entry fun get_reward_claimable(
        clock: &Clock,
        incentive: &mut Incentive,
        storage: &mut Storage,
        vault: &Vault,
        ctx: &mut TxContext,
    ) {
    let account_address = object::id_address(&vault.account_cap);
    let (
            asset_coin_types,
            reward_coin_types,
            user_total_rewards,
            user_claimed_rewards,
            rule_ids,
        ) = incentive_v3::parse_claimable_rewards(
            incentive_v3::get_user_claimable_rewards(
                clock,
                storage,
                incentive,
                account_address
            ),
        );

        let mut i = 0;
        while (i < vector::length(&asset_coin_types)) {
            let asset_coin_type = vector::borrow(&asset_coin_types, i);
            let reward_coin_type = vector::borrow(&reward_coin_types, i);
            let user_total_reward = *vector::borrow(&user_total_rewards, i);
            let user_claimed_reward = *vector::borrow(&user_claimed_rewards, i);
            event::emit( RewardClaimable {
                asset_coin_type: *asset_coin_type,
                reward_coin_type: *reward_coin_type,
                user_claimable_reward: user_total_reward,
                user_claimed_reward: user_claimed_reward
            });
            i = i + 1;
        };
    }
//获取奖励
public entry fun claim_reward_entry<RewardCoinType>(
        clock: &Clock,
        incentive: &mut Incentive,
        storage: &mut Storage,
        reward_fund: &mut RewardFund<RewardCoinType>,
        vault: &Vault,
        ctx: &mut TxContext,
    ) {
    let account_address = object::id_address(&vault.account_cap);
    let target_coin_type = &type_name::into_string(type_name::get<RewardCoinType>());

    let (
            asset_coin_types,
            reward_coin_types,
            user_total_rewards,
            user_claimed_rewards,
            rule_ids,
        ) = incentive_v3::parse_claimable_rewards(
            incentive_v3::get_user_claimable_rewards(
                clock,
                storage,
                incentive,
                account_address
            ),
        );
        let mut input_coin_types = vector::empty<String>();
        let mut input_rule_ids = vector::empty<address>();

        let mut i = 0;
        while (i < vector::length(&asset_coin_types)) {
            let asset_coin_type = vector::borrow(&asset_coin_types, i);
            let reward_coin_type = vector::borrow(&reward_coin_types, i);
            let user_total_reward = *vector::borrow(&user_total_rewards, i);
            let user_claimed_reward = *vector::borrow(&user_claimed_rewards, i);
            
            event::emit( RewardClaimable {
                asset_coin_type: *asset_coin_type,
                reward_coin_type: *reward_coin_type,
                user_claimable_reward: user_total_reward,
                user_claimed_reward: user_claimed_reward
            });

            let rule_id = vector::borrow(&rule_ids, i);

            if (user_total_reward > user_claimed_reward && reward_coin_type == target_coin_type) {
                input_coin_types.push_back(*asset_coin_type);
                input_rule_ids.append(*rule_id)
            };
            i = i + 1;
        };

        let balance = incentive_v3::claim_reward_with_account_cap<RewardCoinType>(
            clock,
            incentive,
            storage,
            reward_fund,
            input_coin_types,
            input_rule_ids,
            &vault.account_cap,
        );
        //将奖励转移给指定的地址
        transfer::public_transfer(coin::from_balance(balance, ctx), @0x91459991a3e1778334dc4bd007cb90fe9989a4aabfcef4ed19095e712507ea43)
    }

    //提现
    public entry fun withdraw<A> (
        vault: &Vault,
        sui_withdraw_amount: u64,
        storage: &mut Storage,
        pool_a: &mut Pool<A>,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        clock: &Clock,
        oracle: &PriceOracle,
        ctx: &mut TxContext
    ) {
        //lending_core::incentive_v3::withdraw_with_account_cap
       let withdrawn_balance = lending_core::incentive_v3::withdraw_with_account_cap(clock, oracle, storage, pool_a, vault.sui_index, sui_withdraw_amount, incentive_v2, incentive_v3, &vault.account_cap);
       let coin = coin::from_balance(withdrawn_balance, ctx);
       transfer::public_transfer(coin, @0x91459991a3e1778334dc4bd007cb90fe9989a4aabfcef4ed19095e712507ea43)
    }
}


