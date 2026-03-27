package com.example.comparateur_app.ui.shoppinglist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.comparateur_app.data.dao.ShoppingListDao
import com.example.comparateur_app.data.dao.ShoppingListItemDao
import com.example.comparateur_app.data.entity.ShoppingList
import com.example.comparateur_app.data.entity.ShoppingListItem
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ShoppingListViewModel @Inject constructor(
    private val shoppingListDao: ShoppingListDao,
    private val shoppingListItemDao: ShoppingListItemDao
) : ViewModel() {

    val allShoppingLists: StateFlow<List<ShoppingList>> = shoppingListDao.getAllShoppingLists()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun addShoppingList(name: String) {
        viewModelScope.launch {
            shoppingListDao.insert(ShoppingList(name = name))
        }
    }

    fun deleteShoppingList(shoppingList: ShoppingList) {
        viewModelScope.launch {
            shoppingListDao.delete(shoppingList)
        }
    }

    fun toggleItemChecked(item: ShoppingListItem) {
        viewModelScope.launch {
            shoppingListItemDao.update(item.copy(isChecked = !item.isChecked))
        }
    }
}
