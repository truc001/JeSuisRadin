package com.example.comparateur_app.data.model

import com.example.comparateur_app.data.entity.Product
import com.example.comparateur_app.data.entity.ShoppingListItem

data class ShoppingListItemWithProduct(
    val item: ShoppingListItem,
    val product: Product
)
