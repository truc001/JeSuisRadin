package com.example.comparateur_app.data.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.comparateur_app.data.entity.ShoppingListItem
import kotlinx.coroutines.flow.Flow

@Dao
interface ShoppingListItemDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(item: ShoppingListItem): Long

    @Update
    suspend fun update(item: ShoppingListItem)

    @Delete
    suspend fun delete(item: ShoppingListItem)

    @Query("SELECT * FROM shopping_list_items WHERE listId = :listId")
    fun getItemsForList(listId: Int): Flow<List<ShoppingListItem>>

    @Query("UPDATE shopping_list_items SET isChecked = :isChecked WHERE id = :itemId")
    suspend fun updateCheckedStatus(itemId: Int, isChecked: Boolean)

    @Query("DELETE FROM shopping_list_items WHERE listId = :listId")
    suspend fun deleteAllItemsFromList(listId: Int)
}
