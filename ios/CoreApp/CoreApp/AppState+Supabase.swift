import Foundation

/// All Supabase network calls live here, kept out of AppState.swift so the
/// property declarations stay readable. Catalog tables (trainers, products,
/// workout_cards, ...) are public-read and shared by every member. Bookings
/// and cart rows are scoped to `device_user_id = DeviceUser.id` — this app
/// doesn't route Apple/Google/phone sign-in through Supabase Auth, so there
/// is no `auth.uid()` to key off; scoping happens by only ever querying
/// this device's own rows, per supabase/schema.sql's RLS policies.
extension AppState {
    /// Call once on launch (see ContentView) to replace the empty catalog
    /// arrays and load this device's bookings/cart from Supabase.
    func loadFromSupabase() async {
        async let trainersRows: [TrainerRow] = Self.fetch("trainers")
        async let productRows: [ProductRow] = Self.fetch("products", select: "*, product_ingredients(*)")
        async let workoutCardRows: [WorkoutCardRow] = Self.fetch("workout_cards", select: "*, exercises(*)")
        async let importantCardRows: [ImportantCardRow] = Self.fetch("important_cards")
        async let foodRecipeRows: [FoodRecipeRow] = Self.fetch("food_recipes")
        async let gymZoneRows: [GymZoneRow] = Self.fetch("gym_zones")
        async let subscriptionPlanRows: [SubscriptionPlanRow] = Self.fetch("subscription_plans")
        async let bookedSessionRows: [BookedSessionRow] = Self.fetchOwn("booked_sessions")
        async let cartLineRows: [CartLineRow] = Self.fetchOwn("cart_items")

        let (trainerRows, productRowsValue, workoutRows, importantRows, foodRows, zoneRows, planRows, sessionRows, cartRows) = await (
            trainersRows, productRows, workoutCardRows, importantCardRows, foodRecipeRows, gymZoneRows, subscriptionPlanRows, bookedSessionRows, cartLineRows
        )

        trainers = trainerRows.map { $0.toModel() }
        products = productRowsValue.map { $0.toModel() }
        beginnerPlanCards = workoutRows.filter { $0.section == "beginner_plan" }.map { $0.toModel() }
        topWorkoutCards = workoutRows.filter { $0.section == "top_workouts" }.map { $0.toModel() }
        importantCards = importantRows.map { $0.toModel() }
        foodRecipes = foodRows.map { $0.toModel() }
        gymZones = zoneRows.map { $0.toModel() }
        subscriptionPlans = planRows.map { $0.toModel() }
        bookedSessions = sessionRows.map { $0.toModel() }
        cart = cartRows.map { $0.toModel() }
    }

    // MARK: Bookings

    func insertSession(_ session: BookedSession) async {
        let row = BookedSessionInsert(
            id: session.id, deviceUserID: DeviceUser.id, date: SupabaseDate.format(session.date),
            title: session.title, trainerName: session.trainerName
        )
        do {
            try await supabase.from("booked_sessions").insert(row).execute()
        } catch {
            print("Supabase insertSession failed: \(error)")
        }
    }

    func updateSessionDate(_ id: UUID, to newDate: Date) async {
        do {
            try await supabase.from("booked_sessions")
                .update(["date": SupabaseDate.format(newDate)])
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            print("Supabase updateSessionDate failed: \(error)")
        }
    }

    func deleteSession(_ id: UUID) async {
        do {
            try await supabase.from("booked_sessions").delete().eq("id", value: id.uuidString).execute()
        } catch {
            print("Supabase deleteSession failed: \(error)")
        }
    }

    // MARK: Cart

    func insertCartLine(_ line: CartLine) async {
        let row = CartLineInsert(id: line.id, deviceUserID: DeviceUser.id, name: line.name, price: line.price)
        do {
            try await supabase.from("cart_items").insert(row).execute()
        } catch {
            print("Supabase insertCartLine failed: \(error)")
        }
    }

    func deleteCartLine(_ id: UUID) async {
        do {
            try await supabase.from("cart_items").delete().eq("id", value: id.uuidString).execute()
        } catch {
            print("Supabase deleteCartLine failed: \(error)")
        }
    }

    func deleteAllCartLines() async {
        do {
            try await supabase.from("cart_items").delete().eq("device_user_id", value: DeviceUser.id).execute()
        } catch {
            print("Supabase deleteAllCartLines failed: \(error)")
        }
    }

    // MARK: Fetch helpers

    private static func fetch<T: Decodable>(_ table: String, select: String = "*") async -> [T] {
        do {
            return try await supabase.from(table).select(select).execute().value
        } catch {
            print("Supabase fetch(\(table)) failed: \(error)")
            return []
        }
    }

    private static func fetchOwn<T: Decodable>(_ table: String, select: String = "*") async -> [T] {
        do {
            return try await supabase.from(table)
                .select(select)
                .eq("device_user_id", value: DeviceUser.id)
                .execute()
                .value
        } catch {
            print("Supabase fetchOwn(\(table)) failed: \(error)")
            return []
        }
    }
}
