/// Tests for Sui Arisan smart contract
#[test_only]
module sui_arisan::arisan_tests {
    use sui::test_scenario::{Self as ts};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::string;
    use sui_arisan::arisan::{Self, Pot, AdminCap};

    // Test addresses
    const ADMIN: address = @0xAD;
    const MEMBER1: address = @0x1;
    const MEMBER2: address = @0x2;
    const MEMBER3: address = @0x3;

    const DEPOSIT_AMOUNT: u64 = 1_000_000_000; // 1 SUI

    // ======== Helper Functions ========

    fun mint_sui(amount: u64, scenario: &mut ts::Scenario): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
    }

    // ======== Tests ========

    #[test]
    fun test_create_pot() {
        let mut scenario = ts::begin(ADMIN);

        // Create pot with 3 members
        let members = vector[MEMBER1, MEMBER2, MEMBER3];
        arisan::create_pot(
            string::utf8(b"Test Arisan"),
            DEPOSIT_AMOUNT,
            members,
            ts::ctx(&mut scenario)
        );

        // Verify pot was created
        ts::next_tx(&mut scenario, ADMIN);
        {
            let pot = ts::take_shared<Pot>(&scenario);
            let (_name, admin, deposit_amt, member_count, period, total, status) = arisan::get_pot_info(&pot);

            assert!(admin == ADMIN, 0);
            assert!(deposit_amt == DEPOSIT_AMOUNT, 1);
            assert!(member_count == 3, 2);
            assert!(period == 1, 3);
            assert!(total == 3, 4);
            assert!(status == 0, 5); // STATUS_DEPOSIT_PHASE

            ts::return_shared(pot);
        };

        // Verify admin cap was created
        {
            let admin_cap = ts::take_from_address<AdminCap>(&scenario, ADMIN);
            ts::return_to_address(ADMIN, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = arisan::ETooManyMembers)]
    fun test_create_pot_too_many_members() {
        let mut scenario = ts::begin(ADMIN);

        // Try to create pot with 11 members (exceeds MAX_MEMBERS)
        let members = vector[
            @0x1, @0x2, @0x3, @0x4, @0x5,
            @0x6, @0x7, @0x8, @0x9, @0xA, @0xB
        ];
        arisan::create_pot(
            string::utf8(b"Too Many"),
            DEPOSIT_AMOUNT,
            members,
            ts::ctx(&mut scenario)
        );

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = arisan::EDuplicateMember)]
    fun test_create_pot_duplicate_members() {
        let mut scenario = ts::begin(ADMIN);

        // Try to create pot with duplicate members
        let members = vector[MEMBER1, MEMBER2, MEMBER1];
        arisan::create_pot(
            string::utf8(b"Duplicates"),
            DEPOSIT_AMOUNT,
            members,
            ts::ctx(&mut scenario)
        );

        ts::end(scenario);
    }

    #[test]
    fun test_deposit() {
        let mut scenario = ts::begin(ADMIN);

        // Create pot
        let members = vector[MEMBER1, MEMBER2, MEMBER3];
        arisan::create_pot(
            string::utf8(b"Test Arisan"),
            DEPOSIT_AMOUNT,
            members,
            ts::ctx(&mut scenario)
        );

        // Member1 deposits
        ts::next_tx(&mut scenario, MEMBER1);
        {
            let mut pot = ts::take_shared<Pot>(&scenario);
            let payment = mint_sui(DEPOSIT_AMOUNT, &mut scenario);

            arisan::deposit(&mut pot, payment, ts::ctx(&mut scenario));

            assert!(arisan::has_deposited(&pot, MEMBER1), 0);
            assert!(arisan::get_balance(&pot) == DEPOSIT_AMOUNT, 1);
            assert!(arisan::get_deposit_count(&pot) == 1, 2);

            ts::return_shared(pot);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = arisan::ENotMember)]
    fun test_deposit_not_member() {
        let mut scenario = ts::begin(ADMIN);

        // Create pot without ADMIN as member
        let members = vector[MEMBER1, MEMBER2, MEMBER3];
        arisan::create_pot(
            string::utf8(b"Test Arisan"),
            DEPOSIT_AMOUNT,
            members,
            ts::ctx(&mut scenario)
        );

        // Admin tries to deposit (not a member)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pot = ts::take_shared<Pot>(&scenario);
            let payment = mint_sui(DEPOSIT_AMOUNT, &mut scenario);

            arisan::deposit(&mut pot, payment, ts::ctx(&mut scenario));

            ts::return_shared(pot);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = arisan::EAlreadyDeposited)]
    fun test_deposit_twice() {
        let mut scenario = ts::begin(ADMIN);

        // Create pot
        let members = vector[MEMBER1, MEMBER2, MEMBER3];
        arisan::create_pot(
            string::utf8(b"Test Arisan"),
            DEPOSIT_AMOUNT,
            members,
            ts::ctx(&mut scenario)
        );

        // Member1 deposits twice
        ts::next_tx(&mut scenario, MEMBER1);
        {
            let mut pot = ts::take_shared<Pot>(&scenario);
            let payment1 = mint_sui(DEPOSIT_AMOUNT, &mut scenario);
            let payment2 = mint_sui(DEPOSIT_AMOUNT, &mut scenario);

            arisan::deposit(&mut pot, payment1, ts::ctx(&mut scenario));
            arisan::deposit(&mut pot, payment2, ts::ctx(&mut scenario)); // Should fail

            ts::return_shared(pot);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = arisan::EInvalidAmount)]
    fun test_deposit_wrong_amount() {
        let mut scenario = ts::begin(ADMIN);

        // Create pot
        let members = vector[MEMBER1, MEMBER2, MEMBER3];
        arisan::create_pot(
            string::utf8(b"Test Arisan"),
            DEPOSIT_AMOUNT,
            members,
            ts::ctx(&mut scenario)
        );

        // Member1 deposits wrong amount
        ts::next_tx(&mut scenario, MEMBER1);
        {
            let mut pot = ts::take_shared<Pot>(&scenario);
            let payment = mint_sui(DEPOSIT_AMOUNT / 2, &mut scenario); // Half amount

            arisan::deposit(&mut pot, payment, ts::ctx(&mut scenario));

            ts::return_shared(pot);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_all_deposits_triggers_draw_ready() {
        let mut scenario = ts::begin(ADMIN);

        // Create pot with 2 members for simplicity
        let members = vector[MEMBER1, MEMBER2];
        arisan::create_pot(
            string::utf8(b"Test Arisan"),
            DEPOSIT_AMOUNT,
            members,
            ts::ctx(&mut scenario)
        );

        // Member1 deposits
        ts::next_tx(&mut scenario, MEMBER1);
        {
            let mut pot = ts::take_shared<Pot>(&scenario);
            let payment = mint_sui(DEPOSIT_AMOUNT, &mut scenario);
            arisan::deposit(&mut pot, payment, ts::ctx(&mut scenario));

            // Status should still be deposit phase
            let (_, _, _, _, _, _, status) = arisan::get_pot_info(&pot);
            assert!(status == 0, 0);

            ts::return_shared(pot);
        };

        // Member2 deposits
        ts::next_tx(&mut scenario, MEMBER2);
        {
            let mut pot = ts::take_shared<Pot>(&scenario);
            let payment = mint_sui(DEPOSIT_AMOUNT, &mut scenario);
            arisan::deposit(&mut pot, payment, ts::ctx(&mut scenario));

            // Status should now be draw ready
            let (_, _, _, _, _, _, status) = arisan::get_pot_info(&pot);
            assert!(status == 1, 1); // STATUS_DRAW_READY

            ts::return_shared(pot);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_view_functions() {
        let mut scenario = ts::begin(ADMIN);

        // Create pot
        let members = vector[MEMBER1, MEMBER2, MEMBER3];
        arisan::create_pot(
            string::utf8(b"My Arisan"),
            DEPOSIT_AMOUNT,
            members,
            ts::ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, MEMBER1);
        {
            let pot = ts::take_shared<Pot>(&scenario);

            // Test view functions
            assert!(arisan::is_pot_member(&pot, MEMBER1), 0);
            assert!(arisan::is_pot_member(&pot, MEMBER2), 1);
            assert!(!arisan::is_pot_member(&pot, ADMIN), 2);

            assert!(!arisan::has_deposited(&pot, MEMBER1), 3);
            assert!(!arisan::has_won(&pot, MEMBER1), 4);

            assert!(arisan::get_balance(&pot) == 0, 5);
            assert!(arisan::get_deposit_count(&pot) == 0, 6);

            let winners = arisan::get_winners(&pot);
            assert!(winners.length() == 0, 7);

            ts::return_shared(pot);
        };

        ts::end(scenario);
    }
}
