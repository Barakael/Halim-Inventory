import '../../../../core/api/products_api.dart';
import '../models/product_model.dart';

class ProductsRemoteDataSource {
  final ProductsApi productsApi;

  const ProductsRemoteDataSource({required this.productsApi});

  Future<List<ProductModel>> getProducts() async {
    try {
      final list = await productsApi.getProducts();
      return list
          .map((e) => ProductModel.fromLaravelJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load products: $e');
    }
  }

  Future<ProductModel> getProductById(String id) async {
    try {
      final response = await productsApi.getProduct(id);
      return ProductModel.fromLaravelJson(response);
    } catch (e) {
      throw Exception('Failed to load product: $e');
    }
  }

  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      final response = await productsApi.getProductByBarcode(barcode);
      return response != null
          ? ProductModel.fromLaravelJson(response)
          : null;
    } catch (e) {
      throw Exception('Failed to load product by barcode: $e');
    }
  }

  /// [data] must match Laravel validation (snake_case): name, barcode, price,
  /// stock, category, optional image, low_stock_threshold.
  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    try {
      final imagePath = data.remove('image_path') as String?;
      final response = await productsApi.createProduct(data);
      var model = ProductModel.fromLaravelJson(response);
      if (imagePath != null && imagePath.isNotEmpty) {
        final uploaded = await productsApi.uploadImage(model.id, imagePath);
        model = ProductModel.fromLaravelJson(uploaded);
      }
      return model;
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  Future<ProductModel> updateProduct(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final imagePath = data.remove('image_path') as String?;
      final response = await productsApi.updateProduct(id, data);
      var model = ProductModel.fromLaravelJson(response);
      if (imagePath != null && imagePath.isNotEmpty) {
        final uploaded = await productsApi.uploadImage(id, imagePath);
        model = ProductModel.fromLaravelJson(uploaded);
      }
      return model;
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await productsApi.deleteProduct(id);
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<List<String>> getCategories() async {
    try {
      return await productsApi.getCategories();
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  Future<ProductModel> updateStock(String id, int quantity) async {
    try {
      final response = await productsApi.updateStock(id, quantity);
      return ProductModel.fromLaravelJson(response);
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }
}
