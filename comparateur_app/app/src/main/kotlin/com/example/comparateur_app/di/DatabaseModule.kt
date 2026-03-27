package com.example.comparateur_app.di

import android.content.Context
import androidx.room.Room
import com.example.comparateur_app.data.AppDatabase
import com.example.comparateur_app.data.dao.*
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            "comparateur_db"
        ).build()
    }

    @Provides
    fun provideProductDao(appDatabase: AppDatabase): ProductDao {
        return appDatabase.productDao()
    }

    @Provides
    fun provideStoreDao(appDatabase: AppDatabase): StoreDao {
        return appDatabase.storeDao()
    }

    @Provides
    fun providePriceDao(appDatabase: AppDatabase): PriceDao {
        return appDatabase.priceDao()
    }

    @Provides
    fun provideShoppingListDao(appDatabase: AppDatabase): ShoppingListDao {
        return appDatabase.shoppingListDao()
    }

    @Provides
    fun provideShoppingListItemDao(appDatabase: AppDatabase): ShoppingListItemDao {
        return appDatabase.shoppingListItemDao()
    }
}
