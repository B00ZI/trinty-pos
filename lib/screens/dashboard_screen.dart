import 'package:Drywich/widgets/expenceTracking.dart';
import 'package:flutter/material.dart';
import 'package:Drywich/widgets/insight_item.dart';
import '../widgets/charts.dart';
import '../widgets/bestSellr.dart';
import '../widgets/bestSellr.dart';

class DashboardScreen extends StatelessWidget {
  final List<Product> myProducts = [
  Product(
    title: 'Wireless Headphones',
    price: '\$79.99',
    rank: '#1',
    rankColor: Colors.amber,
   
  ),
  Product(
    title: 'Smart Watch Series 5',
    price: '\$199.99',
    rank: '#2',
    rankColor: Colors.blue,
    
  ),
  Product(
    title: 'Bluetooth Speaker',
    price: '\$49.99',
    rank: '#3',
    rankColor: Colors.green,
  ),
  Product(
    title: 'Phone Case',
    price: '\$24.99',
    rank: '#4',
    rankColor: Colors.purple,
  ),
];
  final List<SalesData> mySalesData;

  // Remove 'const' from constructor since we have non-constant data
  DashboardScreen({super.key}) : 
    mySalesData = [
      SalesData(month: 'Jan', sales: 5000),
      SalesData(month: 'Feb', sales: 7500),
      SalesData(month: 'Mar', sales: 6200),
      SalesData(month: 'Apr', sales: 8900),
      SalesData(month: 'May', sales: 11000),
    ];
    

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
           
            
            // Info Cards in a row
            Row(
              children: [
                Expanded(
                  child: InfoCard(
                    title: 'Revenue', 
                    value: '12,345 DH', 
                    icon: Icons.attach_money, 
                    color: Colors.green
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InfoCard(
                    title: 'Orders', 
                    value: '150', 
                    icon: Icons.shopping_cart, 
                    color: Colors.blue
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(
                  child: InfoCard(
                    title: 'Expenses', 
                    value: '5,000 DH', 
                    icon: Icons.money_off, 
                    color: Colors.red
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InfoCard(
                    title: 'Profit', 
                    value: '7,345 DH', 
                    icon: Icons.trending_up, 
                    color: Colors.green
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Chart - make sure it has enough height
            Container(
              height: 300,
              child: SalesChartWidget(salesData: mySalesData),
            ),
            const SizedBox(height: 20),
            // Best Sellers Section
            Container(
              height: 200,
              child: ProductCardsRow(
                products: myProducts,
                sectionTitle: 'Best Sellers',
                scrollable: true,
              ),
            ),
            const SizedBox(height: 20),
            // Add more sections as needed
           Container(
            height: 200,
            child: AddableListWidget(),
           )
          ],
        ),
      ),
    );
  }
}