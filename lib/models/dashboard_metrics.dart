class DashboardMetrics {
  final double todayRevenue;
  final double todayOrderCount;
  final double todayExpenses;
  final double todayProfit;
  final double todayFunds;
  
  final double revenueTrend;
  final double ordersTrend;
  final double expensesTrend;
  final double profitTrend;
  
  final bool revenueTrendPositive;
  final bool ordersTrendPositive;
  final bool expensesTrendPositive;
  final bool profitTrendPositive;
  
  final String comparisonLabel;
  final bool fundsAlreadySet;

  const DashboardMetrics({
    this.todayRevenue = 0.0,
    this.todayOrderCount = 0.0,
    this.todayExpenses = 0.0,
    this.todayProfit = 0.0,
    this.todayFunds = 0.0,
    
    this.revenueTrend = 0.0,
    this.ordersTrend = 0.0,
    this.expensesTrend = 0.0,
    this.profitTrend = 0.0,
    
    this.revenueTrendPositive = true,
    this.ordersTrendPositive = true,
    this.expensesTrendPositive = false,
    this.profitTrendPositive = true,
    
    this.comparisonLabel = '',
    this.fundsAlreadySet = false,
  });
}
