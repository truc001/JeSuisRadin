package com.example.comparateur_app.data.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.comparateur_app.data.entity.Price
import kotlinx.coroutines.flow.Flow

@Dao
interface PriceDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(price: Price): Long

    @Update
    suspend fun update(price: Price)

    @Delete
    suspend fun delete(price: Price)

    @Query("SELECT * FROM prices WHERE productId = :productId")
    fun getPricesForProduct(productId: Int): Flow<List<Price>>

    @Query("SELECT * FROM prices WHERE storeId = :storeId")
    fun getPricesAtStore(storeId: Int): Flow<List<Price>>

    @Query("SELECT * FROM prices WHERE productId = :productId AND storeId = :storeId ORDER BY date DESC LIMIT 1")
    suspend fun getLatestPrice(productId: Int, storeId: Int): Price?
}
