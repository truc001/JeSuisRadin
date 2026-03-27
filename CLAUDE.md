# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Android app (Kotlin + Jetpack Compose) for comparing product prices across stores. Source is in `comparateur_app/`.

## Commands

All commands run from `comparateur_app/`:

```bash
./gradlew assembleDebug          # Build debug APK
./gradlew test                   # Run unit tests
./gradlew connectedAndroidTest   # Run instrumented tests (requires device/emulator)
./gradlew clean                  # Clean build
./gradlew lint                   # Run lint checks
./gradlew testDebugUnitTest --tests "com.example.comparateur_app.FooTest"  # Run a single test class
```

## Architecture

**Pattern:** MVVM with Hilt dependency injection, Kotlin Flow for reactivity.

**Key layers:**

- `data/` — Room entities, DAOs, Retrofit API interface (`OpenFoodFactsApi`, base URL: `https://world.openfoodfacts.org/`)
- `di/` — Hilt modules: `DatabaseModule` (Room + DAOs), `NetworkModule` (Retrofit)
- `ui/` — Screens + ViewModels per feature (products, stores, scanner, shopping list)
- `util/` — `BarcodeScannerAnalyzer` (CameraX + ML Kit)

**Navigation:** `NavGraph.kt` with `Navigation Compose`. Routes defined in `Screen.kt` (sealed class): `products`, `stores`, `scan`, `shopping_list`. Bottom nav with 3 tabs.

**Database:** Room (`comparateur_db`, v1). 5 entities: `Product`, `Store`, `Price` (FK to both), `ShoppingList`, `ShoppingListItem`. Type converter for `Date`.

**State:** Each ViewModel exposes `StateFlow<UiState>` collected via `collectAsState()` in Compose screens.

## Tech Stack

| Concern | Library |
|---|---|
| UI | Jetpack Compose + Material 3 |
| DI | Dagger Hilt 2.51.1 |
| DB | Room 2.6.1 (KSP code gen) |
| Network | Retrofit 2.11.0 + Gson |
| Camera | CameraX 1.4.0 |
| Barcode | ML Kit 17.3.0 |
| Permissions | Accompanist 0.36.0 |

## Hilt Setup

- `ComparateurApplication` is annotated `@HiltAndroidApp`
- All Activities/Fragments use `@AndroidEntryPoint`
- ViewModels use `@HiltViewModel` with `@Inject constructor`
- KSP generates Hilt code — rebuild after adding new injection points
