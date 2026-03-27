package com.example.comparateur_app.ui.shoppinglist

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.comparateur_app.data.dao.PriceDao
import com.example.comparateur_app.data.dao.ProductDao
import com.example.comparateur_app.data.dao.ShoppingListDao
import com.example.comparateur_app.data.dao.ShoppingListItemDao
import com.example.comparateur_app.data.entity.ShoppingList
import com.example.comparateur_app.data.entity.ShoppingListItem
import com.example.comparateur_app.data.model.ShoppingListItemWithProduct
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class StoreOptimization(
    val storeName: String,
    val totalPrice: Double,
    val coveredItems: Int,
    val totalItems: Int
)

@HiltViewModel
class ShoppingListDetailViewModel @Inject constructor(
    private val shoppingListDao: ShoppingListDao,
    private val shoppingListItemDao: ShoppingListItemDao,
    private val productDao: ProductDao,
    private val priceDao: PriceDao,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val listId: Int = checkNotNull(savedStateHandle["listId"])

    private val _shoppingList = MutableStateFlow<ShoppingList?>(null)
    val shoppingList: StateFlow<ShoppingList?> = _shoppingList.asStateFlow()

    val items: StateFlow<List<ShoppingListItemWithProduct>> = shoppingListItemDao
        .getItemsWithProductForList(listId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val allProducts = productDao.getAllProducts()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _storeOptimizations = MutableStateFlow<List<StoreOptimization>>(emptyList())
    val storeOptimizations: StateFlow<List<StoreOptimization>> = _storeOptimizations.asStateFlow()

    init {
        viewModelScope.launch {
            _shoppingList.value = shoppingListDao.getShoppingListById(listId)
        }
        viewModelScope.launch {
            items.collect { currentItems -> computeOptimizations(currentItems) }
        }
    }

    fun toggleItem(item: ShoppingListItemWithProduct) {
        viewModelScope.launch {
            shoppingListItemDao.updateCheckedStatus(item.itemId, !item.isChecked)
        }
    }

    fun removeItem(item: ShoppingListItemWithProduct) {
        viewModelScope.launch {
            shoppingListItemDao.delete(
                ShoppingListItem(
                    id = item.itemId,
                    listId = item.listId,
                    productId = item.productId,
                    quantity = item.quantity,
                    isChecked = item.isChecked
                )
            )
        }
    }

    fun addProduct(productId: Int) {
        viewModelScope.launch {
            shoppingListItemDao.insert(ShoppingListItem(listId = listId, productId = productId))
        }
    }

    private suspend fun computeOptimizations(currentItems: List<ShoppingListItemWithProduct>) {
        if (currentItems.isEmpty()) {
            _storeOptimizations.value = emptyList()
            return
        }

        val storeTotals = mutableMapOf<Int, Double>()
        val storeCoverage = mutableMapOf<Int, Int>()
        val storeNames = mutableMapOf<Int, String>()

        for (item in currentItems) {
            try {
                val pws = priceDao.getPricesWithStoreForProduct(item.productId).first()
                // Garder le prix le moins cher par magasin (déjà trié ASC)
                val cheapestByStore = pws.groupBy { it.storeId }
                    .mapValues { (_, prices) -> prices.minByOrNull { it.price }!! }
                for ((storeId, pw) in cheapestByStore) {
                    storeNames[storeId] = pw.storeName
                    storeTotals[storeId] = (storeTotals[storeId] ?: 0.0) + pw.price * item.quantity
                    storeCoverage[storeId] = (storeCoverage[storeId] ?: 0) + 1
                }
            } catch (_: Exception) { /* produit sans prix, ignoré */ }
        }

        _storeOptimizations.value = storeTotals.map { (storeId, total) ->
            StoreOptimization(
                storeName = storeNames[storeId] ?: "Magasin #$storeId",
                totalPrice = total,
                coveredItems = storeCoverage[storeId] ?: 0,
                totalItems = currentItems.size
            )
        }.sortedBy { it.totalPrice }
    }
}
