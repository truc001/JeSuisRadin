package com.example.comparateur_app.data.model

data class ShoppingListItemWithProduct(
    val itemId: Int,
    val listId: Int,
    val productId: Int,
    val productName: String,
    val productBrand: String?,
    val quantity: Int,
    val isChecked: Boolean
)
