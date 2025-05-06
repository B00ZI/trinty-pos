import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/product_item.dart'; // Import the ProductItem widget

class OrderScreen extends StatefulWidget {
  const OrderScreen({Key? key}) : super(key: key);

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final List<OrderItem> _cart = [];
  final List<Product> sampleProducts = [
    Product(
      id: '1',
      name: 'Spaghetti Carbonara',
      price: 12.99,
      category: 'Pasta',
      description: 'Creamy spaghetti with bacon and eggs.',
      imageUrl: 'https://example.com/spaghetti.jpg', // Replace with a valid image URL
      isAvailable: true,
    ),
    Product(
      id: '2',
      name: 'Margherita Pizza',
      price: 10.50,
      category: 'Pizza',
      description: 'Classic pizza with tomato, mozzarella, and basil.',
      imageUrl: 'https://example.com/pizza.jpg', // Replace with a valid image URL
      isAvailable: true,
    ),
  ];

  void _addToCart(Product product) {
    setState(() {
      final existingItem = _cart.firstWhere((item) => item.product.id == product.id, orElse: () => OrderItem(product: product, quantity: 0));

      if (existingItem.quantity > 0){
        existingItem.quantity++;
      } else {
        
        _cart.add(OrderItem(product: product, quantity: 1));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order'),
      ),      
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0), // Add padding here
                  child: ListView.builder(
                    itemCount: sampleProducts.length,
                    itemBuilder: (context, index) => ProductItem(
                      product: sampleProducts[index],
                      onAddToCart: _addToCart,
                    ),
                  ),
                ),
              ),
              Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: _cart.isEmpty
                    ? Center(child: Text('Your cart is empty'))
                    : ListView.builder(
                        itemCount: _cart.length,
                        itemBuilder: (context, index) => ListTile(
                          leading: Text(
                            _cart[index].quantity.toString(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        title: Text(_cart[index].product.name),
                        trailing: Text('\$${_cart[index].subtotal.toStringAsFixed(2)}'),
                      ),
                  ),
            ),
            ],
          ),
        ),
    );
  }
}