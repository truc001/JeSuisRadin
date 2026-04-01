package com.example.comparateur_app.ui.scan

import android.Manifest
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.comparateur_app.data.entity.Product
import com.example.comparateur_app.data.entity.Store
import com.example.comparateur_app.ui.theme.ChipShape
import com.example.comparateur_app.ui.theme.DialogShape
import com.example.comparateur_app.ui.theme.FabShape
import com.example.comparateur_app.util.BarcodeScannerAnalyzer
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import java.util.concurrent.Executors

@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun ScannerScreen(
    viewModel: ScannerViewModel = hiltViewModel(),
    onNavigateToProductDetails: (Int) -> Unit
) {
    val cameraPermissionState = rememberPermissionState(Manifest.permission.CAMERA)
    val scannedProduct by viewModel.scannedProduct.collectAsState()
    val scannedBarcode by viewModel.scannedBarcode.collectAsState()
    val stores by viewModel.allStores.collectAsState()
    val offProductName by viewModel.offProductName.collectAsState()
    val offBrand by viewModel.offBrand.collectAsState()

    if (cameraPermissionState.status.isGranted) {
        Box(modifier = Modifier.fillMaxSize()) {
            CameraPreview(
                onFrameAnalyzed = { viewModel.onFrameAnalyzed() },
                onBarcodeDetected = { viewModel.onBarcodeDetected(it) }
            )
            ScannerOverlay()

            scannedProduct?.let { product ->
                PriceEntryDialog(
                    product = product,
                    stores = stores,
                    onDismiss = { viewModel.resetScannedProduct() },
                    onConfirm = { storeId, price ->
                        viewModel.addPrice(product.id, storeId, price)
                    },
                    onAddStore = { viewModel.addStore(it) }
                )
            }

            scannedBarcode?.let { barcode ->
                UnifiedAddProductAndPriceDialog(
                    barcode = barcode,
                    prefilledName = offProductName ?: "",
                    prefilledBrand = offBrand ?: "",
                    stores = stores,
                    onDismiss = { viewModel.resetScannedProduct() },
                    onConfirm = { name, brand, storeId, price ->
                        viewModel.saveNewProductWithPrice(name, brand, storeId, price)
                    },
                    onAddStore = { viewModel.addStore(it) }
                )
            }
        }
    } else {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Surface(
                shape = FabShape,
                color = MaterialTheme.colorScheme.primaryContainer,
                modifier = Modifier.size(80.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        Icons.Outlined.CameraAlt,
                        contentDescription = null,
                        modifier = Modifier.size(40.dp),
                        tint = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
            }
            Spacer(modifier = Modifier.height(24.dp))
            Text(
                "Permission requise",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                "La camera est necessaire pour scanner les codes-barres",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(24.dp))
            FilledTonalButton(
                onClick = { cameraPermissionState.launchPermissionRequest() },
                shape = MaterialTheme.shapes.medium,
                colors = ButtonDefaults.filledTonalButtonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            ) {
                Text("Autoriser la camera")
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UnifiedAddProductAndPriceDialog(
    barcode: String,
    prefilledName: String,
    prefilledBrand: String,
    stores: List<Store>,
    onDismiss: () -> Unit,
    onConfirm: (String, String?, Int, Double) -> Unit,
    onAddStore: (String) -> Unit
) {
    var name by remember(prefilledName) { mutableStateOf(prefilledName) }
    var brand by remember(prefilledBrand) { mutableStateOf(prefilledBrand) }
    var priceStr by remember { mutableStateOf("") }
    var selectedStore by remember { mutableStateOf<Store?>(null) }
    var expanded by remember { mutableStateOf(false) }
    var showAddStoreDialog by remember { mutableStateOf(false) }

    if (showAddStoreDialog) {
        AddStoreDialogInScan(
            onDismiss = { showAddStoreDialog = false },
            onConfirm = {
                onAddStore(it)
                showAddStoreDialog = false
            }
        )
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                "Nouveau produit",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                Surface(
                    color = MaterialTheme.colorScheme.tertiaryContainer,
                    shape = ChipShape,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        "EAN: $barcode",
                        style = MaterialTheme.typography.labelMedium,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                        color = MaterialTheme.colorScheme.onTertiaryContainer,
                        fontWeight = FontWeight.Medium
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))

                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Nom du produit") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium
                )
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = brand,
                    onValueChange = { brand = it },
                    label = { Text("Marque (optionnel)") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium
                )

                HorizontalDivider(
                    modifier = Modifier.padding(vertical = 16.dp),
                    color = MaterialTheme.colorScheme.outlineVariant
                )

                OutlinedTextField(
                    value = priceStr,
                    onValueChange = { priceStr = it },
                    label = { Text("Prix (\u20AC)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium
                )

                Spacer(modifier = Modifier.height(16.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    ExposedDropdownMenuBox(
                        expanded = expanded,
                        onExpandedChange = { expanded = !expanded },
                        modifier = Modifier.weight(1f)
                    ) {
                        OutlinedTextField(
                            value = selectedStore?.name ?: "Selectionner un magasin",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text("Magasin") },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                            modifier = Modifier
                                .menuAnchor(MenuAnchorType.PrimaryNotEditable, true)
                                .fillMaxWidth(),
                            shape = MaterialTheme.shapes.medium
                        )

                        ExposedDropdownMenu(
                            expanded = expanded,
                            onDismissRequest = { expanded = false }
                        ) {
                            stores.forEach { store ->
                                DropdownMenuItem(
                                    text = { Text(store.name) },
                                    onClick = {
                                        selectedStore = store
                                        expanded = false
                                    }
                                )
                            }
                        }
                    }

                    FilledTonalIconButton(
                        onClick = { showAddStoreDialog = true },
                        modifier = Modifier.padding(start = 8.dp),
                        shape = ChipShape
                    ) {
                        Icon(Icons.Default.Add, contentDescription = "Ajouter un magasin")
                    }
                }
            }
        },
        confirmButton = {
            FilledTonalButton(
                onClick = {
                    val price = priceStr.toDoubleOrNull()
                    if (name.isNotBlank() && price != null && selectedStore != null) {
                        onConfirm(name, brand.ifBlank { null }, selectedStore!!.id, price)
                    }
                },
                enabled = name.isNotBlank() && priceStr.toDoubleOrNull() != null && selectedStore != null,
                shape = MaterialTheme.shapes.medium,
                colors = ButtonDefaults.filledTonalButtonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            ) {
                Text("Tout enregistrer")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Annuler")
            }
        },
        shape = DialogShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PriceEntryDialog(
    product: Product,
    stores: List<Store>,
    onDismiss: () -> Unit,
    onConfirm: (Int, Double) -> Unit,
    onAddStore: (String) -> Unit
) {
    var priceStr by remember { mutableStateOf("") }
    var selectedStore by remember { mutableStateOf<Store?>(null) }
    var expanded by remember { mutableStateOf(false) }
    var showAddStoreDialog by remember { mutableStateOf(false) }

    if (showAddStoreDialog) {
        AddStoreDialogInScan(
            onDismiss = { showAddStoreDialog = false },
            onConfirm = {
                onAddStore(it)
                showAddStoreDialog = false
            }
        )
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                "Ajouter un prix",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Column {
                Surface(
                    color = MaterialTheme.colorScheme.surfaceContainerHigh,
                    shape = ChipShape,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text(
                            product.name,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        if (product.brand != null) {
                            Text(
                                product.brand,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                OutlinedTextField(
                    value = priceStr,
                    onValueChange = { priceStr = it },
                    label = { Text("Prix (\u20AC)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium
                )

                Spacer(modifier = Modifier.height(16.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    ExposedDropdownMenuBox(
                        expanded = expanded,
                        onExpandedChange = { expanded = !expanded },
                        modifier = Modifier.weight(1f)
                    ) {
                        OutlinedTextField(
                            value = selectedStore?.name ?: "Selectionner un magasin",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text("Magasin") },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                            modifier = Modifier
                                .menuAnchor(MenuAnchorType.PrimaryNotEditable, true)
                                .fillMaxWidth(),
                            shape = MaterialTheme.shapes.medium
                        )

                        ExposedDropdownMenu(
                            expanded = expanded,
                            onDismissRequest = { expanded = false }
                        ) {
                            stores.forEach { store ->
                                DropdownMenuItem(
                                    text = { Text(store.name) },
                                    onClick = {
                                        selectedStore = store
                                        expanded = false
                                    }
                                )
                            }
                        }
                    }

                    FilledTonalIconButton(
                        onClick = { showAddStoreDialog = true },
                        modifier = Modifier.padding(start = 8.dp),
                        shape = ChipShape
                    ) {
                        Icon(Icons.Default.Add, contentDescription = "Ajouter un magasin")
                    }
                }
            }
        },
        confirmButton = {
            FilledTonalButton(
                onClick = {
                    val price = priceStr.toDoubleOrNull()
                    if (price != null && selectedStore != null) {
                        onConfirm(selectedStore!!.id, price)
                    }
                },
                enabled = priceStr.toDoubleOrNull() != null && selectedStore != null,
                shape = MaterialTheme.shapes.medium,
                colors = ButtonDefaults.filledTonalButtonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            ) {
                Text("Enregistrer")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Annuler")
            }
        },
        shape = DialogShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
    )
}

@Composable
fun AddStoreDialogInScan(
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var name by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                "Nouveau magasin",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Nom du magasin") },
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium
            )
        },
        confirmButton = {
            FilledTonalButton(
                onClick = { onConfirm(name) },
                enabled = name.isNotBlank(),
                shape = MaterialTheme.shapes.medium,
                colors = ButtonDefaults.filledTonalButtonColors(
                    containerColor = MaterialTheme.colorScheme.tertiaryContainer,
                    contentColor = MaterialTheme.colorScheme.onTertiaryContainer
                )
            ) {
                Text("Ajouter")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Annuler")
            }
        },
        shape = DialogShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
    )
}

@Composable
fun ScannerOverlay() {
    val primaryColor = MaterialTheme.colorScheme.primary

    Canvas(modifier = Modifier.fillMaxSize()) {
        val width = size.width
        val height = size.height
        val rectSize = width * 0.7f
        val rectTop = (height - rectSize) / 2f
        val rectLeft = (width - rectSize) / 2f
        val cornerRadius = 28.dp.toPx()

        drawRect(
            color = Color.Black.copy(alpha = 0.55f),
            size = size
        )

        val rectPath = Path().apply {
            addRoundRect(
                RoundRect(
                    rect = Rect(
                        offset = Offset(rectLeft, rectTop),
                        size = Size(rectSize, rectSize)
                    ),
                    cornerRadius = CornerRadius(cornerRadius, cornerRadius)
                )
            )
        }

        drawPath(
            path = rectPath,
            color = Color.Transparent,
            blendMode = BlendMode.Clear
        )

        drawRoundRect(
            color = primaryColor,
            topLeft = Offset(rectLeft, rectTop),
            size = Size(rectSize, rectSize),
            cornerRadius = CornerRadius(cornerRadius, cornerRadius),
            style = Stroke(width = 3.dp.toPx())
        )
    }
}

@Composable
fun CameraPreview(
    onFrameAnalyzed: () -> Unit,
    onBarcodeDetected: (String) -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }

    AndroidView(
        factory = { ctx ->
            val previewView = PreviewView(ctx)
            val executor = ContextCompat.getMainExecutor(ctx)
            cameraProviderFuture.addListener({
                val cameraProvider = cameraProviderFuture.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }

                val imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also {
                        it.setAnalyzer(
                            Executors.newSingleThreadExecutor(),
                            BarcodeScannerAnalyzer(onFrameAnalyzed, onBarcodeDetected)
                        )
                    }

                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                try {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner,
                        cameraSelector,
                        preview,
                        imageAnalysis
                    )
                } catch (e: Exception) {
                }
            }, executor)
            previewView
        },
        modifier = Modifier.fillMaxSize()
    )
}
