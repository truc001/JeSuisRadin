package com.example.comparateur_app.data

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.example.comparateur_app.data.converters.Converters
import com.example.comparateur_app.data.dao.*
import com.example.comparateur_app.data.entity.*

@Database(
    entities = [
        Product::class,
        Store::class,
        Price::class,
        ShoppingList::class,
        ShoppingListItem::class
    ],
    version = 1,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun productDao(): ProductDao
    abstract fun storeDao(): StoreDao
    abstract fun priceDao(): PriceDao
    abstract fun shoppingListDao(): ShoppingListDao
    abstract fun shoppingListItemDao(): ShoppingListItemDao
}
