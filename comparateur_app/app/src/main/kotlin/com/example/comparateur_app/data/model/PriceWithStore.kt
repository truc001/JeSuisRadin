package com.example.comparateur_app.data.model

import java.util.Date

data class PriceWithStore(
    val priceId: Int,
    val price: Double,
    val date: Date,
    val storeId: Int,
    val storeName: String
)
