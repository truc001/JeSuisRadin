package com.example.comparateur_app.ui.products

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.comparateur_app.data.dao.PriceDao
import com.example.comparateur_app.data.dao.ProductDao
import com.example.comparateur_app.data.dao.StoreDao
import com.example.comparateur_app.data.entity.Price
import com.example.comparateur_app.data.entity.Product
import com.example.comparateur_app.data.entity.Store
import com.example.comparateur_app.data.model.PriceWithStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject

@HiltViewModel
class ProductDetailViewModel @Inject constructor(
    private val productDao: ProductDao,
    private val priceDao: PriceDao,
    private val storeDao: StoreDao,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val productId: Int = checkNotNull(savedStateHandle["productId"])

    private val _product = MutableStateFlow<Product?>(null)
    val product: StateFlow<Product?> = _product.asStateFlow()

    val pricesWithStore: StateFlow<List<PriceWithStore>> = priceDao
        .getPricesWithStoreForProduct(productId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val stores: StateFlow<List<Store>> = storeDao.getAllStores()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        viewModelScope.launch {
            _product.value = productDao.getProductById(productId)
        }
    }

    fun addPrice(storeId: Int, price: Double) {
        viewModelScope.launch {
            priceDao.insert(Price(productId = productId, storeId = storeId, price = price, date = Date()))
        }
    }

    fun addStore(name: String) {
        viewModelScope.launch {
            storeDao.insert(Store(name = name))
        }
    }
}
