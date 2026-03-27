package com.example.comparateur_app.ui.navigation

sealed class Screen(val route: String) {
    object Products : Screen("products")
    object Stores : Screen("stores")
    object Scan : Screen("scan")
    object ShoppingList : Screen("shopping_list")
}
