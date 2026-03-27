package com.example.comparateur_app.ui.shoppinglist

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.comparateur_app.data.entity.ShoppingList

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShoppingListScreen(
    onNavigateToList: (Int) -> Unit,
    viewModel: ShoppingListViewModel = hiltViewModel()
) {
    val shoppingLists by viewModel.allShoppingLists.collectAsState()
    var showDialog by remember { mutableStateOf(false) }
    var newListName by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        "Listes de courses",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.ExtraBold
                    )
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        },
        floatingActionButton = {
            LargeFloatingActionButton(
                onClick = { showDialog = true },
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
                shape = MaterialTheme.shapes.large
            ) {
                Icon(Icons.Default.Add, contentDescription = "Ajouter une liste")
            }
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        if (shoppingLists.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "Aucune liste de courses",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(shoppingLists) { list ->
                    ShoppingListCard(
                        list = list,
                        onDelete = { viewModel.deleteShoppingList(list) },
                        onClick = { onNavigateToList(list.id) }
                    )
                }
            }
        }

        if (showDialog) {
            AlertDialog(
                onDismissRequest = {
                    showDialog = false
                    newListName = ""
                },
                title = { Text("Nouvelle liste", fontWeight = FontWeight.Bold) },
                text = {
                    OutlinedTextField(
                        value = newListName,
                        onValueChange = { newListName = it },
                        label = { Text("Nom de la liste") },
                        modifier = Modifier.fillMaxWidth(),
                        shape = MaterialTheme.shapes.medium
                    )
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (newListName.isNotBlank()) {
                                viewModel.addShoppingList(newListName)
                                newListName = ""
                                showDialog = false
                            }
                        },
                        enabled = newListName.isNotBlank(),
                        shape = MaterialTheme.shapes.medium
                    ) {
                        Text("Ajouter")
                    }
                },
                dismissButton = {
                    TextButton(onClick = {
                        showDialog = false
                        newListName = ""
                    }) {
                        Text("Annuler")
                    }
                },
                shape = MaterialTheme.shapes.extraLarge
            )
        }
    }
}

@Composable
fun ShoppingListCard(
    list: ShoppingList,
    onDelete: () -> Unit,
    onClick: () -> Unit
) {
    ElevatedCard(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = list.name,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            IconButton(
                onClick = onDelete,
                colors = IconButtonDefaults.iconButtonColors(
                    contentColor = MaterialTheme.colorScheme.error.copy(alpha = 0.7f)
                )
            ) {
                Icon(Icons.Default.Delete, contentDescription = "Supprimer")
            }
        }
    }
}
