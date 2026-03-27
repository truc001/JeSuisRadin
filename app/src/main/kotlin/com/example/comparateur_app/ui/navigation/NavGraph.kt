package com.example.comparateur_app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.outlined.Place
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.example.comparateur_app.ui.products.ProductListScreen
import com.example.comparateur_app.ui.shoppinglist.ShoppingListScreen
import com.example.comparateur_app.ui.stores.StoreListScreen

@Composable
fun MainScreen() {
    val navController = rememberNavController()
    
    Scaffold(
        bottomBar = {
            BottomNavigationBar(navController = navController)
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = Screen.Products.route,
            modifier = Modifier.padding(paddingValues)
        ) {
            composable(Screen.Products.route) {
                ProductListScreen(
                    onNavigateToProductDetails = { productId ->
                        // Navigate to details if implemented
                    }
                )
            }
            composable(Screen.Stores.route) {
                StoreListScreen()
            }
            composable(Screen.ShoppingList.route) {
                ShoppingListScreen()
            }
        }
    }
}

@Composable
fun BottomNavigationBar(navController: NavHostController) {
    val items = listOf(
        NavigationItem(
            "Produits", 
            Screen.Products.route, 
            Icons.Filled.Search, 
            Icons.Outlined.Search
        ),
        NavigationItem(
            "Magasins", 
            Screen.Stores.route, 
            Icons.Filled.Place, 
            Icons.Outlined.Place
        ),
        NavigationItem(
            "Courses", 
            Screen.ShoppingList.route, 
            Icons.Filled.ShoppingCart, 
            Icons.Outlined.ShoppingCart
        )
    )
    
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    NavigationBar(
        containerColor = MaterialTheme.colorScheme.surface,
        tonalElevation = NavigationBarDefaults.Elevation
    ) {
        items.forEach { item ->
            val isSelected = currentRoute == item.route
            NavigationBarItem(
                icon = { 
                    Icon(
                        imageVector = if (isSelected) item.filledIcon else item.outlinedIcon, 
                        contentDescription = item.title 
                    ) 
                },
                label = { Text(item.title, style = MaterialTheme.typography.labelMedium) },
                selected = isSelected,
                onClick = {
                    navController.navigate(item.route) {
                        navController.graph.startDestinationRoute?.let { route ->
                            popUpTo(route) {
                                saveState = true
                            }
                        }
                        launchSingleTop = true
                        restoreState = true
                    }
                },
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = MaterialTheme.colorScheme.primary,
                    selectedTextColor = MaterialTheme.colorScheme.primary,
                    indicatorColor = MaterialTheme.colorScheme.primaryContainer
                )
            )
        }
    }
}

data class NavigationItem(
    val title: String, 
    val route: String, 
    val filledIcon: androidx.compose.ui.graphics.vector.ImageVector,
    val outlinedIcon: androidx.compose.ui.graphics.vector.ImageVector
)
