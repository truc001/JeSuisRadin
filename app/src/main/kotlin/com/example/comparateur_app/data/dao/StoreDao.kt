package com.example.comparateur_app.data.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.comparateur_app.data.entity.Store
import kotlinx.coroutines.flow.Flow

@Dao
interface StoreDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(store: Store): Long

    @Update
    suspend fun update(store: Store)

    @Delete
    suspend fun delete(store: Store)

    @Query("SELECT * FROM stores WHERE id = :id")
    suspend fun getStoreById(id: Int): Store?

    @Query("SELECT * FROM stores")
    fun getAllStores(): Flow<List<Store>>
}
