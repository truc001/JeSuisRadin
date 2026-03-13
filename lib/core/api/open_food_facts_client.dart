import 'package:openfoodfacts/openfoodfacts.dart';

class OpenFoodFactsClient {
  OpenFoodFactsClient() {
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'ComparateurApp',
      version: '1.0.0',
    );
  }

  Future<ProductResultV3?> fetchProduct(String barcode) async {
    final configuration = ProductQueryConfiguration(
      barcode,
      language: OpenFoodFactsLanguage.FRENCH,
      country: OpenFoodFactsCountry.FRANCE,
      fields: [
        ProductField.NAME,
        ProductField.BRANDS,
        ProductField.IMAGE_FRONT_URL,
        ProductField.QUANTITY,
        ProductField.CATEGORIES_TAGS,
      ],
      version: ProductQueryVersion.v3,
    );

    try {
      return await OpenFoodAPIClient.getProductV3(configuration);
    } catch (e) {
      return null;
    }
  }
}
