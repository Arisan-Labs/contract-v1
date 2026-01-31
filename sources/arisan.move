/// Sui Group Pot / Arisan - On-chain rotating savings system
/// A decentralized arisan (Indonesian rotating savings) implementation on Sui blockchain
#[allow(lint(public_random, public_entry))]
module sui_arisan::arisan {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::random::{Self, Random};
    use sui::event;
    use std::string::String;

    // ======== Constants ========
    const MAX_MEMBERS_LIMIT: u64 = 100;

    // Status codes
    const STATUS_DEPOSIT_PHASE: u8 = 0;
    const STATUS_DRAW_READY: u8 = 1;
    const STATUS_COMPLETED: u8 = 2;

    // ======== Errors ========
    const ENotMember: u64 = 1;
    const EAlreadyDeposited: u64 = 2;
    const EInvalidAmount: u64 = 3;
    const ETooManyMembers: u64 = 4;
    const EAlreadyJoined: u64 = 5;
    const EPotFull: u64 = 6;
    const EInvalidAdminCap: u64 = 8;
    const ENoEligibleWinners: u64 = 9;
    const ENotInDepositPhase: u64 = 10;
    const ENotInDrawPhase: u64 = 11;
    const ENotJoined: u64 = 12;
    const EInvalidMaxMembers: u64 = 13;

    // ======== Structs ========

    /// Admin capability for managing the pot
    public struct AdminCap has key, store {
        id: UID,
        pot_id: ID
    }

    /// Main Pot object - shared across all members
    public struct Pot has key {
        id: UID,
        name: String,
        admin: address,
        max_members: u64,
        deposit_amount: u64,
        current_members: Table<address, bool>,
        members_list: vector<address>,
        current_period: u64,
        total_periods: u64,
        deposits_this_period: Table<address, bool>,
        winners: vector<address>,
        balance: Balance<SUI>,
        status: u8
    }

    // ======== Events ========

    public struct PotCreated has copy, drop {
        pot_id: ID,
        admin: address,
        name: String,
        deposit_amount: u64,
        max_members: u64,
        total_periods: u64
    }

    public struct MemberJoined has copy, drop {
        pot_id: ID,
        member: address,
        current_members: u64
    }

    public struct DepositMade has copy, drop {
        pot_id: ID,
        member: address,
        amount: u64,
        period: u64
    }

    public struct WinnerDrawn has copy, drop {
        pot_id: ID,
        winner: address,
        amount: u64,
        period: u64
    }

    public struct PotCompleted has copy, drop {
        pot_id: ID,
        total_periods: u64
    }

    // ======== Public Functions ========

    /// Create a new arisan pot
    /// Admin specifies name, max members, fixed deposit amount, and cycle duration
    public entry fun create_pot(
        name: String,
        max_members: u64,
        deposit_amount: u64,
        total_periods: u64,
        ctx: &mut TxContext
    ) {
        assert!(max_members > 0 && max_members <= MAX_MEMBERS_LIMIT, EInvalidMaxMembers);
        assert!(total_periods > 0, EInvalidMaxMembers);

        let pot_uid = object::new(ctx);
        let pot_id = pot_uid.to_inner();

        let pot = Pot {
            id: pot_uid,
            name,
            admin: ctx.sender(),
            max_members,
            deposit_amount,
            current_members: table::new(ctx),
            members_list: vector::empty(),
            current_period: 1,
            total_periods,
            deposits_this_period: table::new(ctx),
            winners: vector::empty(),
            balance: balance::zero(),
            status: STATUS_DEPOSIT_PHASE
        };

        let admin_cap = AdminCap {
            id: object::new(ctx),
            pot_id
        };

        event::emit(PotCreated {
            pot_id,
            admin: ctx.sender(),
            name: pot.name,
            deposit_amount,
            max_members,
            total_periods
        });

        transfer::share_object(pot);
        transfer::transfer(admin_cap, ctx.sender());
    }

    /// Member joins the arisan pot
    public entry fun join_pot(
        pot: &mut Pot,
        ctx: &mut TxContext
    ) {
        let sender = ctx.sender();

        // Check if already joined
        assert!(!pot.current_members.contains(sender), EAlreadyJoined);

        // Check if pot is full
        assert!(pot.current_members.length() < pot.max_members, EPotFull);

        // Check if pot is still in deposit phase
        assert!(pot.status == STATUS_DEPOSIT_PHASE, ENotInDepositPhase);

        // Add member to both table and list
        pot.current_members.add(sender, true);
        pot.members_list.push_back(sender);

        event::emit(MemberJoined {
            pot_id: pot.id.to_inner(),
            member: sender,
            current_members: pot.current_members.length()
        });
    }

    /// Member deposits their contribution for the current period
    public entry fun deposit(
        pot: &mut Pot,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(pot.status == STATUS_DEPOSIT_PHASE, ENotInDepositPhase);

        let sender = ctx.sender();

        // Check if sender is a member (has joined)
        assert!(pot.current_members.contains(sender), ENotJoined);

        // Check if already deposited this period
        assert!(!pot.deposits_this_period.contains(sender), EAlreadyDeposited);

        // Check correct amount
        let payment_value = payment.value();
        assert!(payment_value == pot.deposit_amount, EInvalidAmount);

        // Add deposit
        pot.balance.join(payment.into_balance());
        pot.deposits_this_period.add(sender, true);

        event::emit(DepositMade {
            pot_id: pot.id.to_inner(),
            member: sender,
            amount: payment_value,
            period: pot.current_period
        });

        // Check if all members have deposited
        if (pot.deposits_this_period.length() == pot.current_members.length()) {
            pot.status = STATUS_DRAW_READY;
        }
    }

    /// Admin triggers the draw to select a winner
    /// Uses Sui's native randomness for fair selection
    public entry fun draw_winner(
        pot: &mut Pot,
        admin_cap: &AdminCap,
        r: &Random,
        ctx: &mut TxContext
    ) {
        // Validate admin cap
        assert!(admin_cap.pot_id == pot.id.to_inner(), EInvalidAdminCap);
        assert!(pot.status == STATUS_DRAW_READY, ENotInDrawPhase);

        // Get eligible winners (members who haven't won yet)
        let eligible = get_eligible_winners(&pot.members_list, &pot.winners);
        assert!(eligible.length() > 0, ENoEligibleWinners);

        // Use Sui random to select winner
        let mut generator = random::new_generator(r, ctx);
        let winner_index = random::generate_u64_in_range(&mut generator, 0, eligible.length());
        let winner = eligible[winner_index];

        // Calculate payout (all deposits from this period)
        let payout_amount = pot.balance.value();
        let payout = coin::from_balance(pot.balance.split(payout_amount), ctx);

        // Update state
        pot.winners.push_back(winner);

        event::emit(WinnerDrawn {
            pot_id: pot.id.to_inner(),
            winner,
            amount: payout_amount,
            period: pot.current_period
        });

        // Transfer payout to winner
        transfer::public_transfer(payout, winner);

        // Prepare for next period or complete
        if (pot.winners.length() == pot.total_periods) {
            pot.status = STATUS_COMPLETED;
            event::emit(PotCompleted {
                pot_id: pot.id.to_inner(),
                total_periods: pot.total_periods
            });
        } else {
            // Reset for next period
            pot.current_period = pot.current_period + 1;

            // Clear deposits table for next period
            let mut i = 0;
            while (i < pot.members_list.length()) {
                let member = pot.members_list[i];
                if (pot.deposits_this_period.contains(member)) {
                    pot.deposits_this_period.remove(member);
                };
                i = i + 1;
            };

            pot.status = STATUS_DEPOSIT_PHASE;
        }
    }

    // ======== View Functions ========

    /// Get pot information
    public fun get_pot_info(pot: &Pot): (String, address, u64, u64, u64, u64, u64, u8) {
        (
            pot.name,
            pot.admin,
            pot.deposit_amount,
            pot.current_members.length(),
            pot.max_members,
            pot.current_period,
            pot.total_periods,
            pot.status
        )
    }

    /// Get current balance of the pot
    public fun get_balance(pot: &Pot): u64 {
        pot.balance.value()
    }

    /// Check if an address is a member (joined pot)
    public fun is_pot_member(pot: &Pot, addr: address): bool {
        pot.current_members.contains(addr)
    }

    /// Check if a member has deposited this period
    public fun has_deposited(pot: &Pot, addr: address): bool {
        pot.deposits_this_period.contains(addr)
    }

    /// Check if a member has already won
    public fun has_won(pot: &Pot, addr: address): bool {
        is_member(&pot.winners, addr)
    }

    /// Get list of members who deposited this period
    public fun get_deposit_count(pot: &Pot): u64 {
        pot.deposits_this_period.length()
    }

    /// Get list of past winners
    public fun get_winners(pot: &Pot): vector<address> {
        pot.winners
    }

    // ======== Internal Functions ========

    fun is_member(members: &vector<address>, addr: address): bool {
        let mut i = 0;
        let len = members.length();
        while (i < len) {
            if (members[i] == addr) {
                return true
            };
            i = i + 1;
        };
        false
    }

    fun get_eligible_winners(members: &vector<address>, winners: &vector<address>): vector<address> {
        let mut eligible = vector::empty<address>();
        let mut i = 0;
        let len = members.length();
        while (i < len) {
            let member = members[i];
            if (!is_member(winners, member)) {
                eligible.push_back(member);
            };
            i = i + 1;
        };
        eligible
    }
}
